require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_password = ENV["NISA_PASSWORD"]
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ENV["NISA_PASSWORD"] = "test-nisa-password-2026"
    Rails.cache.clear
  end

  teardown do
    ENV["NISA_PASSWORD"] = @original_password
    Rails.cache = @original_cache_store
  end

  test "login screen is modern and does not render the incident workspace before sign-in" do
    get login_url

    assert_response :success
    assert_select "h2", "Tekrar hoş geldin, Nisa"
    assert_select "input[name='username'][value='Nisa']"
    assert_select "input[name='password'][type='password']"
    assert_select "link[rel='icon'][href='/favicon.svg']"
    assert_no_match(/ITSM Incident Management/, response.body)
  end

  test "a protected page returns to its original path after successful Nisa login" do
    get root_url
    assert_redirected_to login_url

    post login_url, params: { username: "Nisa", password: ENV.fetch("NISA_PASSWORD") }

    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Nisa"
    assert_equal "Nisa", Actor.find(session[:actor_id]).name
  end

  test "invalid credentials do not create a session" do
    post login_url, params: { username: "Nisa", password: "incorrect-password" }

    assert_response :unprocessable_entity
    assert_includes response.body, "Kullanıcı adı veya şifre doğrulanamadı."
    assert_nil session[:actor_id]
  end

  test "login is disabled when the server password is missing or too short" do
    ENV["NISA_PASSWORD"] = "short"

    get login_url
    assert_response :success
    assert_select "input[type='submit'][disabled]"

    post login_url, params: { username: "Nisa", password: "short" }
    assert_response :unprocessable_entity
    assert_nil session[:actor_id]
  end

  test "logout clears the session and subsequent workspace access returns to login" do
    sign_in_as_nisa
    delete logout_url

    assert_redirected_to login_url
    get root_url
    assert_redirected_to login_url
  end

  test "login attempts are rate limited" do
    10.times do
      post login_url, params: { username: "Nisa", password: "incorrect-password" }
      assert_response :unprocessable_entity
    end

    post login_url, params: { username: "Nisa", password: "incorrect-password" }
    assert_response :too_many_requests
    assert_includes response.body, "Çok fazla giriş denemesi."
  end
end
