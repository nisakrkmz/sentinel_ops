require "test_helper"

class TriageSchemaTest < ActiveSupport::TestCase
  def valid_output
    {
      "priority" => "P2",
      "impact" => "department",
      "urgency" => "medium",
      "category" => "Network Infrastructure",
      "affected_service" => "Global VPN Gateway",
      "assignment_group" => "Global Network Operations",
      "major_incident_candidate" => { "value" => false, "probability" => 0.05 },
      "duplicate_of" => { "incident_id" => nil, "probability" => 0.0 },
      "is_actionable" => true,
      "needs_human" => { "value" => false, "probability" => 0.2, "reason_code" => "not_required" },
      "sla_breach_risk" => "medium",
      "rationale" => "One region is affected and a workaround remains available."
    }
  end

  test "accepts the typed triage contract" do
    assert Triage::Schema.valid?(valid_output)
  end

  test "rejects out of catalog fields, invalid probability, missing keys, and extra actions" do
    output = valid_output.deep_dup
    output["priority"] = "P0"
    output["category"] = "made-up-category"
    output["needs_human"]["probability"] = 1.1
    output["execute_action"] = "restart production"
    output.delete("impact")

    errors = Triage::Schema.validate(output)

    assert errors.any? { |error| error.include?("$.impact is required") }
    assert errors.any? { |error| error.include?("$.priority must be one of") }
    assert errors.any? { |error| error.include?("$.category must be one of") }
    assert errors.any? { |error| error.include?("$.needs_human.probability is above maximum") }
    assert errors.any? { |error| error.include?("$.execute_action is not allowed") }
  end
end
