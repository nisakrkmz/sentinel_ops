require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache_store
  end

  def signup(overrides = {})
    post signup_url, params: { user: {
      name: "Mert Kaya", email: "mert@example.com", password: "long-enough-pass", password_confirmation: "long-enough-pass"
    }.merge(overrides) }
  end

  test "signup page renders a database-backed registration form" do
    get signup_url

    assert_response :success
    assert_select "input[name='user[email]']"
    assert_select "input[name='user[password_confirmation]']"
  end

  test "signup stores a hashed password, creates a human actor and signs the user in" do
    assert_difference [ "User.count", "Actor.human.count" ], 1 do
      signup
    end

    user = User.find_by!(email: "mert@example.com")
    assert_redirected_to root_url
    assert_equal user.id, session[:user_id]
    assert user.actor.human?
    assert_equal "Mert Kaya", user.actor.name
    assert_not_includes user.password_digest, "long-enough-pass"
    assert user.authenticate("long-enough-pass")
    assert_not user.authenticate("wrong-password")
  end

  test "signup rejects duplicates, short passwords and mismatched confirmations" do
    signup
    delete logout_url

    assert_no_difference "User.count" do
      signup(email: "MERT@example.com")
      assert_response :unprocessable_entity
      assert_includes response.body, "Bu e-posta ile kayıtlı bir hesap var"

      signup(email: "short@example.com", password: "short", password_confirmation: "short")
      assert_includes response.body, "en az 10 karakter"

      signup(email: "mismatch@example.com", password_confirmation: "different-pass-1")
      assert_includes response.body, "Şifre tekrarı eşleşmiyor"
    end
  end

  test "a second user with the same display name gets a distinct actor" do
    first = User.create!(name: "Mert Kaya", email: "first@example.com", password: "long-enough-pass")
    second = User.create!(name: "Mert Kaya", email: "second@example.com", password: "long-enough-pass")

    assert_not_equal first.actor, second.actor
    assert_equal "Mert Kaya (second@example.com)", second.actor.name
  end
end
