require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  setup do
    @actor = Actor.create!(
      kind: :agent,
      name: "Resolver Agent",
      scopes: [ "incidents:create", "kb:read" ]
    )
    @pepper = "test-pepper-not-for-production"
  end

  test "issues a scoped token and stores only its digest" do
    token = ApiToken.issue!(actor: @actor, scopes: [ "incidents:create" ], pepper: @pepper)

    assert token.plaintext_token.present?
    assert token.allows?("incidents:create")
    assert_not token.allows?("incidents:resolve")
    assert_not_equal token.plaintext_token, token.token_digest
    assert_equal token.id, ApiToken.find_by!(token_digest: token.token_digest).id
  end

  test "authentication checks the pepper and records last use" do
    token = ApiToken.issue!(actor: @actor, scopes: [ "kb:read" ], pepper: @pepper)

    assert_nil ApiToken.authenticate(token.plaintext_token, pepper: "wrong-pepper")
    assert_nil token.reload.last_used_at
    assert_equal token.id, ApiToken.authenticate(token.plaintext_token, pepper: @pepper).id
    assert_not_nil token.reload.last_used_at
  end

  test "revoked and expired tokens cannot authenticate" do
    revoked = ApiToken.issue!(actor: @actor, scopes: [], pepper: @pepper)
    expired = ApiToken.issue!(actor: @actor, scopes: [], pepper: @pepper)
    revoked.revoke!
    expired.update!(expires_at: 1.minute.ago)

    assert_nil ApiToken.authenticate(revoked.plaintext_token, pepper: @pepper)
    assert_nil ApiToken.authenticate(expired.plaintext_token, pepper: @pepper)
  end

  test "token scopes cannot exceed actor scopes and inactive actors cannot authenticate" do
    assert_raises(ActiveRecord::RecordInvalid) do
      ApiToken.issue!(actor: @actor, scopes: [ "incidents:resolve" ], pepper: @pepper)
    end

    token = ApiToken.issue!(actor: @actor, scopes: [ "kb:read" ], pepper: @pepper)
    @actor.update!(active: false)

    assert_nil ApiToken.authenticate(token.plaintext_token, pepper: @pepper)
  end

  test "cannot issue a token for an inactive actor" do
    @actor.update!(active: false)

    assert_raises(ActiveRecord::RecordInvalid) do
      ApiToken.issue!(actor: @actor, scopes: [ "kb:read" ], pepper: @pepper)
    end
  end

  test "refuses to issue or authenticate tokens without a pepper" do
    assert_raises(ArgumentError) do
      ApiToken.issue!(actor: @actor, scopes: [], pepper: nil)
    end

    assert_raises(ArgumentError) do
      ApiToken.authenticate("secret-token", pepper: nil)
    end
  end
end
