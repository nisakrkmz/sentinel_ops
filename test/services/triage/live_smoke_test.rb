require "test_helper"
require "tmpdir"

class TriageLiveSmokeTest < ActiveSupport::TestCase
  class StubProvider
    attr_reader :provider, :model, :received

    def initialize(output: nil, error: nil)
      @provider = "test_provider"
      @model = "test-model"
      @output = output
      @error = error
      @received = nil
    end

    def call(incident)
      raise @error if @error

      @received = incident
      @output
    end
  end

  setup do
    @output_directory = Dir.mktmpdir("sentinel-live-smoke")
  end

  teardown do
    FileUtils.remove_entry(@output_directory)
  end

  test "records a schema-validated provider result without storing ticket text" do
    provider = StubProvider.new(output: valid_output)
    report, path = Triage::LiveSmoke.call(provider:, output_directory: @output_directory)
    saved_report = JSON.parse(File.read(path))

    assert_equal "completed", report.fetch("status")
    assert_equal "SAP ERP", provider.received.service_affected
    assert_equal "test_provider", saved_report.fetch("provider")
    assert_equal "test-model", saved_report.fetch("model")
    assert_equal "P2", saved_report.dig("decision", "priority")
    assert_not_includes File.read(path), "month-end SAP posting"
    assert_match(/_triage\.json\z/, path.to_s)
  end

  test "records provider errors without exposing error messages" do
    report, path = Triage::LiveSmoke.call(
      provider: StubProvider.new(error: Triage::ProviderError.new("provider_timeout", "secret provider response")),
      output_directory: @output_directory
    )

    assert_equal "failed", report.fetch("status")
    assert_equal "provider_timeout", report.fetch("error_code")
    assert_not_includes File.read(path), "secret provider response"
  end

  private

  def valid_output
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
      "rationale" => "The reported impact is limited to one department."
    }
  end
end
