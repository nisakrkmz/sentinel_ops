require "test_helper"

class TriageRunnerTest < ActiveSupport::TestCase
  class StubProvider
    attr_reader :provider, :model, :calls

    def initialize(output: nil, error: nil)
      @provider = "test_provider"
      @model = "test-model"
      @output = output
      @error = error
      @calls = 0
    end

    def call(_incident)
      @calls += 1
      raise @error if @error

      @output
    end
  end

  setup do
    @incident = Incident.create!(
      short_description: "Multiple users cannot access payroll",
      description: "The payroll service is failing for one department.",
      service_affected: "unknown"
    )
  end

  def valid_output(overrides = {})
    {
      "priority" => "P2",
      "impact" => "department",
      "urgency" => "medium",
      "category" => "Enterprise Software",
      "affected_service" => "SAP ERP",
      "assignment_group" => "Enterprise ERP Operations",
      "major_incident_candidate" => { "value" => false, "probability" => 0.1 },
      "duplicate_of" => { "incident_id" => nil, "probability" => 0.0 },
      "is_actionable" => true,
      "needs_human" => { "value" => false, "probability" => 0.1, "reason_code" => "not_required" },
      "sla_breach_risk" => "low",
      "rationale" => "One department is affected and the service remains available."
    }.merge(overrides)
  end

  test "persists validated provider output and applies triage fields" do
    provider = StubProvider.new(output: valid_output)
    expected_input_digest = Digest::SHA256.hexdigest(JSON.generate(
      short_description: @incident.short_description,
      description: @incident.description,
      service_affected: @incident.service_affected,
      category: @incident.category
    ))

    result = Triage::Runner.call(@incident, provider: provider)

    assert result.completed?
    assert_equal "done", @incident.reload.triage_status
    assert_equal "p2_high", @incident.priority
    assert_equal "SAP ERP", @incident.service_affected
    assert_equal "Enterprise ERP Operations", @incident.assignment_group
    assert_equal "test_provider", result.decision.provider
    assert_equal "triage-v1", result.decision.prompt_version
    assert_equal expected_input_digest, result.decision.input_digest
  end

  test "needs-human decisions remain typed and mark the incident for handoff" do
    provider = StubProvider.new(
      output: valid_output(
        "needs_human" => { "value" => true, "probability" => 0.93, "reason_code" => "low_confidence" }
      )
    )

    result = Triage::Runner.call(@incident, provider: provider)

    assert result.completed?
    assert_equal "needs_human", @incident.reload.triage_status
    assert_equal true, result.decision.output_json.dig("needs_human", "value")
  end

  test "provider failure is audited and leaves ticket pending without fabricated triage" do
    provider = StubProvider.new(error: Triage::ProviderError.new("provider_timeout", "provider timed out"))
    original_priority = @incident.priority

    result = Triage::Runner.call(@incident, provider: provider)

    assert_not result.completed?
    assert_equal "pending", @incident.reload.triage_status
    assert_equal original_priority, @incident.priority
    assert_equal "failed", result.decision.status
    assert_equal "provider_timeout", result.decision.error_code
    assert_equal({}, result.decision.output_json)
  end

  test "invalid provider output is retried once only by provider adapter and rejected by runner" do
    provider = StubProvider.new(output: { "priority" => "P4" })

    result = Triage::Runner.call(@incident, provider: provider)

    assert_not result.completed?
    assert_equal "invalid_provider_output", result.error_code
    assert_equal 1, provider.calls
    assert_equal "pending", @incident.reload.triage_status
  end
end
