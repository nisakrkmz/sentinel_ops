require "test_helper"

class ActorTest < ActiveSupport::TestCase
  test "actor kind and scoped ownership are persisted" do
    actor = Actor.create!(
      kind: :agent,
      name: "Monitoring Agent",
      owner: "SentinelOps",
      scopes: [ "incidents:create", "kb:read" ]
    )

    assert actor.agent?
    assert_equal [ "incidents:create", "kb:read" ], actor.reload.scopes
    assert actor.active?
  end

  test "demo UI actor is explicitly identified as unauthenticated" do
    actor = Actor.demo_ui_operator

    assert actor.human?
    assert_includes actor.name, "unauthenticated"
    assert_equal actor.id, Actor.demo_ui_operator.id
  end
end
