require "test_helper"

class AgentWorkflowRunnerTest < ActiveSupport::TestCase
  FakeRagResult = Struct.new(:status, :decision, keyword_init: true)

  setup do
    @actor = Actor.create!(kind: :agent, name: "Workflow Test Agent", scopes: [])
    @incident = Incident.create!(
      short_description: "VPN address pool exhaustion",
      description: "Remote users cannot establish a connection.",
      service_affected: "Global VPN Gateway",
      priority: :p3_moderate,
      triage_status: "done",
      opened_by_actor: @actor
    )
    @triage = @incident.decisions.create!(
      actor: @actor,
      kind: :triage,
      provider: "test",
      output_json: {
        "priority" => "P3",
        "needs_human" => { "value" => false, "probability" => 0.1, "reason_code" => "not_required" },
        "major_incident_candidate" => { "value" => false, "probability" => 0.01 },
        "assignment_group" => "Global Network Operations"
      }
    )
  end

  test "provider unavailability creates a pending audit and human handoff without a fabricated answer" do
    @incident.update!(triage_status: "pending")
    @triage.update!(status: :failed, output_json: {}, error_code: "provider_not_configured")

    result = AgentWorkflow::Runner.call(@incident)

    assert_equal "handoff", result.status
    assert_equal "provider_unavailable", result.handoff.reason_code
    assert_equal "pending", result.incident.triage_status
    assert_equal({}, result.handoff.brief.fetch("resolution"))
    assert_equal "handoff", result.policy_decision.output_json.fetch("action")
    assert_includes @incident.timeline_events.pluck(:event_type), "agent_handoff"
  end

  test "triage that requires a human still hands off, with cited Incident Memory evidence in the brief" do
    @incident.update!(triage_status: "needs_human")
    @triage.update!(output_json: @triage.output_json.deep_merge(
      "needs_human" => { "value" => true, "probability" => 0.95, "reason_code" => "ambiguous_impact" }
    ))

    result = AgentWorkflow::Runner.call(@incident, rag_runner: grounded_rag_result)

    assert_equal "handoff", result.status
    assert_equal "needs_human", result.handoff.reason_code
    assert_not result.incident.resolved?
    assert_equal [ "agent-workflow-grounded-memory-root-cause" ], result.handoff.brief.fetch("sources")
  end

  test "pending triage never runs resolution generation" do
    @incident.update!(triage_status: "pending")
    @triage.update!(status: :failed, output_json: {}, error_code: "provider_timeout")

    result = AgentWorkflow::Runner.call(@incident, rag_runner: ->(_incident) { flunk "RAG must not run without a completed triage" })

    assert_equal "provider_unavailable", result.handoff.reason_code
    assert_empty @incident.decisions.resolution
  end

  test "P1 proposal enters human approval and is never auto-resolved" do
    @incident.update!(priority: :p1_critical)
    result = AgentWorkflow::Runner.call(@incident, rag_runner: grounded_rag_result)

    assert_equal "approval_required", result.status
    assert_equal "high_priority", result.handoff.reason_code
    assert_not result.incident.resolved?
    assert_equal "approval_required", result.policy_decision.output_json.fetch("action")
    assert_equal [ "agent-workflow-grounded-memory-root-cause" ], result.handoff.brief.fetch("sources")
  end

  test "eligible low-priority incident auto-resolves only with verified root-cause citation" do
    result = AgentWorkflow::Runner.call(@incident, rag_runner: grounded_rag_result)

    assert_equal "auto_resolve", result.status
    assert result.incident.resolved?
    assert_equal "Root cause validated from historical outage.", result.incident.root_cause_analysis
    assert_nil result.handoff
    assert_includes @incident.timeline_events.pluck(:event_type), "agent_auto_resolved"
  end

  private

  def grounded_rag_result
    article = KnowledgeArticle.create!(
      slug: "agent-workflow-grounded-memory",
      title: "Grounded VPN memory",
      affected_service: "Global VPN Gateway",
      category: "Network Infrastructure",
      source: "synthetic_seed",
      symptoms: "The address pool is exhausted.",
      root_cause: "Root cause validated from historical outage.",
      resolution_steps: [ "Review concurrent session capacity." ],
      verification: "A test tunnel receives an address.",
      approved: true
    )
    article.rebuild_chunks!
    chunk = article.knowledge_chunks.find_by!(section: "root-cause")
    output = {
      "status" => "suggested",
      "steps" => [ { "text" => "Review the pool capacity.", "citations" => [ chunk.chunk_id ] } ],
      "citations" => [ chunk.chunk_id ],
      "confidence" => 0.95,
      "insufficient_evidence" => false
    }
    decision = @incident.decisions.create!(
      actor: @actor,
      kind: :resolution,
      provider: "test-llm",
      model: "test-model",
      output_json: output,
      confidence: 0.95,
      sources: [ chunk.chunk_id ]
    )
    ->(_incident) { FakeRagResult.new(status: "suggested", decision: decision) }
  end
end
