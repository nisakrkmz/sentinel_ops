require "test_helper"

class HitlPolicyTest < ActiveSupport::TestCase
  setup do
    @incident = Incident.create!(
      short_description: "Policy test incident",
      service_affected: "Global VPN Gateway",
      priority: :p3_moderate,
      triage_status: "done"
    )
    @actor = Actor.create!(kind: :agent, name: "Policy Test Agent", scopes: [])
    @triage = Decision.create!(
      incident: @incident,
      actor: @actor,
      kind: :triage,
      provider: "test",
      output_json: {
        "priority" => "P3",
        "needs_human" => { "value" => false, "probability" => 0.1, "reason_code" => "not_required" },
        "major_incident_candidate" => { "value" => false, "probability" => 0.01 }
      }
    )
    @resolution = Decision.create!(
      incident: @incident,
      actor: @actor,
      kind: :resolution,
      provider: "test",
      confidence: 0.95,
      sources: [ "vpn-root-cause" ],
      output_json: { "status" => "suggested", "confidence" => 0.95, "steps" => [] }
    )
  end

  test "permits autonomous resolution only for grounded high-confidence P3/P4 non-critical incidents" do
    result = evaluate(verification_passed: true, root_cause_evidenced: true)

    assert_equal "auto_resolve", result.action
    assert_equal "policy_eligible", result.reason_code
    assert_equal 0.95, result.confidence
  end

  test "requires human approval for P1/P2 and major incident candidates" do
    @incident.update!(priority: :p1_critical)
    assert_equal "approval_required", evaluate(verification_passed: true, root_cause_evidenced: true).action

    @incident.update!(priority: :p3_moderate)
    @triage.update!(output_json: @triage.output_json.deep_merge(
      "major_incident_candidate" => { "value" => true, "probability" => 0.96 }
    ))
    result = evaluate(verification_passed: true, root_cause_evidenced: true)
    assert_equal "approval_required", result.action
    assert_equal "major_incident_candidate", result.reason_code
  end

  test "hands off when human review is required, evidence is insufficient, or confidence is low" do
    @triage.update!(output_json: @triage.output_json.deep_merge(
      "needs_human" => { "value" => true, "probability" => 0.9, "reason_code" => "manual_review" }
    ))
    assert_equal "needs_human", evaluate(verification_passed: true, root_cause_evidenced: true).reason_code

    @triage.update!(output_json: @triage.output_json.deep_merge(
      "needs_human" => { "value" => false, "probability" => 0.1, "reason_code" => "not_required" }
    ))
    assert_equal "citation_verification_failed", evaluate(verification_passed: false, root_cause_evidenced: true).reason_code
    assert_equal "citation_verification_failed", evaluate(verification_passed: true, root_cause_evidenced: false).reason_code

    @resolution.update!(confidence: 0.5, output_json: @resolution.output_json.merge("confidence" => 0.5))
    assert_equal "low_confidence", evaluate(verification_passed: true, root_cause_evidenced: true).reason_code
  end

  test "treats configured critical services as requiring human approval" do
    @incident.update!(service_affected: "SAP ERP")

    result = evaluate(verification_passed: true, root_cause_evidenced: true)

    assert_equal "approval_required", result.action
    assert_equal "critical_service", result.reason_code
  end

  private

  def evaluate(verification_passed:, root_cause_evidenced:)
    Hitl::Policy.evaluate(
      incident: @incident,
      triage_decision: @triage,
      resolution_decision: @resolution,
      verification_passed: verification_passed,
      root_cause_evidenced: root_cause_evidenced
    )
  end
end
