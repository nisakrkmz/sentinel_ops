require "test_helper"

class DecisionTest < ActiveSupport::TestCase
  test "stores typed model provenance and JSON decision output" do
    actor = Actor.create!(kind: :agent, name: "Triage Agent")
    incident = Incident.create!(short_description: "Storage failure", service_affected: "Storage")
    decision = incident.decisions.create!(
      actor: actor,
      kind: "triage",
      provider: "llm_json",
      model: "test-model",
      prompt_version: "triage-v1",
      input_digest: "sha256:sample",
      output_json: { priority: "P2", needs_human: { value: false } },
      confidence: 0.82,
      latency_ms: 245,
      cost_estimate: 0.001,
      sources: [ "INC000840" ]
    )

    assert_equal incident, decision.reload.incident
    assert_equal actor, decision.actor
    assert_equal "P2", decision.output_json.fetch("priority")
    assert_equal [ "INC000840" ], decision.sources
  end

  test "rejects out-of-range confidence and invalid JSON output shape" do
    incident = Incident.create!(short_description: "Network failure", service_affected: "Network")
    decision = incident.decisions.new(
      kind: "triage",
      provider: "llm_json",
      output_json: [ "not", "an", "object" ],
      confidence: 1.5,
      sources: []
    )

    assert_not decision.valid?
    assert_includes decision.errors.attribute_names, :confidence
    assert_includes decision.errors.attribute_names, :output_json
  end
end
