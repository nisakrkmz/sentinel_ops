require "digest"
require "json"

module Triage
  class Runner
    Result = Struct.new(:status, :decision, :error_code, keyword_init: true) do
      def completed?
        status == "completed"
      end
    end

    def self.call(incident, provider: nil)
      new(incident, provider).call
    end

    def initialize(incident, provider)
      @incident = incident
      @provider = provider
    end

    def call
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @provider ||= DecisionProviders::Factory.build
      output = @provider.call(@incident)
      errors = Schema.validate(output)
      raise ProviderError.new("invalid_provider_output", errors.join("; ")) if errors.any?

      digest = input_digest
      decision = persist_success(output, elapsed_ms(started_at), digest)
      Result.new(status: "completed", decision: decision)
    rescue ProviderError => error
      Rails.logger.warn("Triage pending for incident #{@incident.id}: #{error.code}")
      decision = persist_failure(error.code, elapsed_ms(started_at))
      Result.new(status: "pending", decision: decision, error_code: error.code)
    end

    private

    def persist_success(output, latency_ms, digest)
      actor = triage_actor
      decision = nil
      @incident.with_lock do
        decision = Decision.transaction do
          @incident.update!(
            priority: priority_value(output.fetch("priority")),
            category: output.fetch("category"),
            service_affected: output.fetch("affected_service"),
            assignment_group: output.fetch("assignment_group"),
            triage_status: output.fetch("needs_human").fetch("value") ? "needs_human" : "done"
          )
          @incident.decisions.create!(
            actor: actor,
            kind: :triage,
            provider: @provider.provider,
            model: @provider.model,
            prompt_version: DecisionProviders::OpenAiCompatible::PROMPT_VERSION,
            input_digest: digest,
            output_json: output,
            latency_ms: latency_ms,
            sources: []
          )
        end
      end
      decision
    end

    def persist_failure(code, latency_ms)
      decision = @incident.decisions.create!(
        actor: triage_actor,
        kind: :triage,
        provider: @provider&.provider.presence || "unconfigured",
        model: @provider&.model,
        prompt_version: DecisionProviders::OpenAiCompatible::PROMPT_VERSION,
        input_digest: input_digest,
        output_json: {},
        latency_ms: latency_ms,
        sources: [],
        status: :failed,
        error_code: code
      )
      @incident.update!(triage_status: :pending)
      decision
    end

    def triage_actor
      Actor.find_or_create_by!(kind: :agent, name: "SentinelOps Triage Agent") do |actor|
        actor.owner = "SentinelOps"
        actor.scopes = []
      end
    end

    def priority_value(priority)
      {
        "P1" => "p1_critical",
        "P2" => "p2_high",
        "P3" => "p3_moderate",
        "P4" => "p4_low"
      }.fetch(priority)
    end

    def input_digest
      Digest::SHA256.hexdigest(JSON.generate(
        short_description: @incident.short_description,
        description: @incident.description,
        service_affected: @incident.service_affected,
        category: @incident.category
      ))
    end

    def elapsed_ms(started_at)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    end
  end
end
