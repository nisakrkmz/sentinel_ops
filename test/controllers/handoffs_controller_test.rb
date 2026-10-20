require "test_helper"

class HandoffsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @incident = Incident.create!(
      short_description: "VPN pool exhausted",
      service_affected: "Global VPN Gateway",
      priority: :p2_high
    )
    @agent = Actor.create!(kind: :agent, name: "Review Test Agent", scopes: [])
    @handoff = @incident.handoffs.create!(
      from_actor: @agent,
      to_actor_or_group: "Service Desk",
      reason_code: "high_priority",
      brief: {
        "summary" => @incident.short_description,
        "resolution" => {
          "steps" => [ { "text" => "Review the address pool.", "citations" => [] } ]
        }
      }
    )
  end

  test "approval queue shows open handoffs and allows a human to approve and resolve" do
    get handoffs_url
    assert_response :success
    assert_includes response.body, @incident.number
    assert_includes response.body, "Onay Kuyruğu"

    post accept_handoff_url(@handoff), params: {
      review_action: "approve",
      resolution_notes: "Address pool capacity was increased.",
      root_cause: "The concurrent session limit was reached.",
      verification: "A test tunnel received an address."
    }

    assert_redirected_to incident_url(@incident)
    assert_equal "resolved", @incident.reload.state
    assert_equal "accepted", @handoff.reload.status
    assert_equal "approved", @incident.decisions.verify.order(:created_at).last.output_json["action"]
    assert_equal "pending", @incident.kb_candidates.sole.status
  end

  test "rejecting an agent proposal records feedback without resolving the incident" do
    post reject_handoff_url(@handoff), params: { feedback: "Evidence does not match this outage." }

    assert_redirected_to handoffs_url
    assert_equal "rejected", @handoff.reload.status
    assert_not @incident.reload.resolved?
    feedback = @incident.decisions.verify.order(:created_at).last
    assert_equal "rejected", feedback.output_json["action"]
    assert_equal "Evidence does not match this outage.", feedback.output_json["feedback"]
  end
end
