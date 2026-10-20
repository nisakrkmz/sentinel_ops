require "yaml"

module Hitl
  class Policy
    Result = Struct.new(:action, :reason_code, :confidence, keyword_init: true)

    def self.evaluate(incident:, triage_decision:, resolution_decision:, verification_passed:, root_cause_evidenced:)
      new(incident, triage_decision, resolution_decision, verification_passed, root_cause_evidenced).evaluate
    end

    def initialize(incident, triage_decision, resolution_decision, verification_passed, root_cause_evidenced)
      @incident = incident
      @triage_decision = triage_decision
      @resolution_decision = resolution_decision
      @verification_passed = verification_passed
      @root_cause_evidenced = root_cause_evidenced
    end

    def evaluate
      return result("handoff", "provider_unavailable") if @triage_decision&.failed? || @incident.triage_status == "pending"

      triage = @triage_decision&.output_json || {}
      return result("handoff", "needs_human") if triage.dig("needs_human", "value")
      return result("handoff", "provider_unavailable") unless @resolution_decision&.completed?
      return result("handoff", "insufficient_evidence") unless resolution_output["status"] == "suggested"
      return result("handoff", "citation_verification_failed") unless @verification_passed && @root_cause_evidenced
      return result("handoff", "low_confidence") if confidence.nil? || confidence < settings.fetch("minimum_resolution_confidence")

      return result("approval_required", "major_incident_candidate") if triage.dig("major_incident_candidate", "value")
      return result("approval_required", "high_priority") if settings.fetch("approval_priorities").include?(@incident.priority)
      return result("approval_required", "critical_service") if settings.fetch("critical_services").include?(@incident.service_affected)
      return result("auto_resolve", "policy_eligible") if settings.fetch("auto_resolve_priorities").include?(@incident.priority)

      result("handoff", "policy_not_configured")
    end

    private

    def confidence
      resolution_output["confidence"]
    end

    def resolution_output
      @resolution_decision&.output_json || {}
    end

    def settings
      @settings ||= YAML.safe_load_file(
        Rails.root.join("config/hitl_policy.yml"),
        aliases: true
      ).fetch(Rails.env).deep_stringify_keys
    end

    def result(action, reason_code)
      Result.new(action: action, reason_code: reason_code, confidence: confidence)
    end
  end
end
