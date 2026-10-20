require "yaml"
require "digest"
require "json"

module AgentWorkflow
  class Runner
    Result = Struct.new(:status, :incident, :triage_decision, :resolution_decision, :policy_decision, :handoff, :error_code, keyword_init: true)

    def self.call(incident, rag_runner: Rag::Workflow)
      new(incident, rag_runner).call
    end

    def initialize(incident, rag_runner)
      @incident = incident
      @rag_runner = rag_runner
    end

    def call
      Current.set(actor: orchestration_actor) do
        run
      end
    end

    private

    def run
      return Result.new(status: "already_resolved", incident: incident) if incident.resolved? || incident.closed?

      triage = incident.decisions.triage.order(created_at: :desc).first
      triage ||= begin
        Triage::Runner.call(incident)
        incident.decisions.triage.order(created_at: :desc).first
      end
      record_trace("agent_triage", "Triage #{triage&.status || 'pending'}; provider #{triage&.provider || 'unconfigured'}.")

      if triage.nil? || triage.failed? || incident.triage_status.in?(%w[pending needs_human])
        return apply_policy(triage, nil, verification_passed: false, root_cause_evidenced: false)
      end

      rag_result = @rag_runner.call(incident)
      resolution = rag_result.decision
      record_trace("agent_rag", "Incident Memory #{rag_result.status}; #{resolution&.sources&.length || 0} cited chunks.")
      citations = resolution&.sources || []
      chunks = KnowledgeChunk.joins(:knowledge_article)
        .where(knowledge_articles: { approved: true })
        .where(chunk_id: citations)
      valid_ids = chunks.pluck(:chunk_id)
      verification_passed = citations.any? && citations.length == valid_ids.length
      root_cause_evidenced = chunks.any? { |chunk| chunk.section == "root-cause" }
      apply_policy(triage, resolution, verification_passed: verification_passed, root_cause_evidenced: root_cause_evidenced)
    rescue Rag::ProviderError => error
      Rails.logger.warn("Agent workflow pending for incident #{incident.id}: #{error.code}")
      apply_policy(incident.decisions.triage.order(created_at: :desc).first, nil, verification_passed: false, root_cause_evidenced: false, error_code: error.code)
    end

    def apply_policy(triage, resolution, verification_passed:, root_cause_evidenced:, error_code: nil)
      policy = Hitl::Policy.evaluate(
        incident: incident,
        triage_decision: triage,
        resolution_decision: resolution,
        verification_passed: verification_passed,
        root_cause_evidenced: root_cause_evidenced
      )
      decision = incident.decisions.create!(
        actor: orchestration_actor,
        kind: :route,
        provider: "hitl-policy",
        model: "configured-rules",
        prompt_version: "hitl-policy-v1",
        input_digest: Digest::SHA256.hexdigest(JSON.generate(
          incident_id: incident.id,
          triage_decision_id: triage&.id,
          resolution_decision_id: resolution&.id
        )),
        output_json: {
          "action" => policy.action,
          "reason_code" => policy.reason_code,
          "confidence" => policy.confidence,
          "verification_passed" => verification_passed,
          "root_cause_evidenced" => root_cause_evidenced
        },
        confidence: policy.confidence,
        latency_ms: nil,
        sources: resolution&.sources || []
      )
      record_trace("agent_policy", "Policy selected #{policy.action} (#{policy.reason_code}).")

      handoff = case policy.action
      when "auto_resolve"
        auto_resolve!(resolution)
        nil
      when "approval_required", "handoff"
        create_handoff(policy, triage, resolution, error_code)
      end
      Result.new(
        status: policy.action,
        incident: incident.reload,
        triage_decision: triage,
        resolution_decision: resolution,
        policy_decision: decision,
        handoff: handoff,
        error_code: error_code
      )
    end

    def auto_resolve!(decision)
      output = decision.output_json
      chunks = KnowledgeChunk.includes(:knowledge_article).where(chunk_id: decision.sources)
      root_causes = chunks.map { |chunk| chunk.knowledge_article.root_cause }.uniq
      notes = output.fetch("steps").map { |step| step.fetch("text") }.join("\n")
      root_cause = root_causes.join("\n")
      incident.resolve!(resolution_notes: notes, root_cause: root_cause)
      record_trace("agent_auto_resolved", "Agent resolved under HITL policy; cited chunks: #{decision.sources.join(', ')}.")
    end

    def create_handoff(policy, triage, resolution, error_code)
      group = triage&.output_json&.fetch("assignment_group", nil).presence ||
        settings.fetch("human_review_group")
      existing = incident.handoffs.open.where(reason_code: policy.reason_code).order(created_at: :desc).first
      return existing if existing

      brief = {
        "summary" => incident.short_description,
        "description" => incident.description,
        "reason_code" => policy.reason_code,
        "agent_reason" => error_code || policy.reason_code,
        "triage" => triage&.output_json || {},
        "resolution" => resolution&.output_json || {},
        "sources" => resolution&.sources || [],
        "next_step" => next_step(policy)
      }
      handoff = incident.handoffs.create!(
        from_actor: orchestration_actor,
        to_actor_or_group: group,
        reason_code: policy.reason_code,
        confidence: policy.confidence,
        brief: brief
      )
      incident.update!(triage_status: "needs_human") unless policy.reason_code == "provider_unavailable"
      record_trace("agent_handoff", "Handoff opened for #{group} (#{policy.reason_code}).")
      handoff
    end

    def next_step(policy)
      if policy.action == "approval_required"
        "Review the cited proposal and approve, correct, or reject it. The agent did not close this incident."
      else
        "Review the incident and continue triage; no resolution action was executed."
      end
    end

    def record_trace(event_type, message)
      incident.timeline_events.create!(actor: orchestration_actor, event_type: event_type, message: message)
    end

    def orchestration_actor
      @orchestration_actor ||= Actor.find_or_create_by!(kind: :agent, name: "SentinelOps Incident Agent") do |actor|
        actor.owner = "SentinelOps"
        actor.scopes = []
      end
    end

    def settings
      @settings ||= YAML.safe_load_file(
        Rails.root.join("config/hitl_policy.yml"),
        aliases: true
      ).fetch(Rails.env).deep_stringify_keys
    end

    attr_reader :incident
  end
end
