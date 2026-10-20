require "test_helper"

class HandoffTest < ActiveSupport::TestCase
  test "records an open human handoff with its brief and actor" do
    agent = Actor.create!(kind: :agent, name: "Triage Agent")
    incident = Incident.create!(short_description: "Payment failures", service_affected: "Payments")
    handoff = incident.handoffs.create!(
      from_actor: agent,
      to_actor_or_group: "Major Incident Team",
      reason_code: "major_incident_candidate",
      confidence: 0.94,
      brief: { summary: "Checkout failures across regions", next_step: "Review gateway health" }
    )

    assert handoff.open?
    assert_equal "Major Incident Team", handoff.to_actor_or_group
    assert_equal "Checkout failures across regions", handoff.brief.fetch("summary")
    assert_equal agent, handoff.from_actor
  end

  test "rejects unsupported status and malformed handoff brief" do
    agent = Actor.create!(kind: :agent, name: "Resolver Agent")
    incident = Incident.create!(short_description: "Email unavailable", service_affected: "Email")
    handoff = incident.handoffs.new(
      from_actor: agent,
      to_actor_or_group: "Service Desk",
      reason_code: "low_confidence",
      brief: [ "not", "an", "object" ],
      status: "unknown"
    )

    assert_not handoff.valid?
    assert_includes handoff.errors.attribute_names, :status
    assert_includes handoff.errors.attribute_names, :brief
  end
end
