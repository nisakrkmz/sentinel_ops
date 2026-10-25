require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @user = User.create!(name: "Ayşe Demir", email: "ayse@example.com", password: "correct-horse-battery")
  end

  teardown do
    Rails.cache = @original_cache_store
  end

  test "login screen asks for email and password without any server-side password setup" do
    get login_url

    assert_response :success
    assert_select "input[name='email'][type='email']"
    assert_select "input[name='password'][type='password']"
    assert_select "input[type='submit'][disabled]", count: 0
    assert_select "a[href='#{signup_path}']"
    assert_select "link[rel='icon'][href='/favicon.svg']"
    assert_no_match(/NISA_PASSWORD|ITSM Incident Management/, response.body)
  end

  test "a protected page returns to its original path after a database-backed login" do
    get handoffs_url
    assert_redirected_to login_url

    post login_url, params: { email: "AYSE@example.com ", password: "correct-horse-battery" }

    assert_redirected_to handoffs_url
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Ayşe Demir"
    assert_equal @user.id, session[:user_id]
    assert_not_nil @user.reload.last_sign_in_at
  end

  test "UI actions are attributed to the signed-in user's actor" do
    post login_url, params: { email: @user.email, password: "correct-horse-battery" }
    post incidents_url, params: { incident: { short_description: "Printer offline", requested_by: "Caller", service_affected: "SAP ERP", priority: "p4_low", category: "Hardware" } }

    assert_equal @user.actor, Incident.order(:id).last.opened_by_actor
  end

  test "invalid credentials and unknown emails do not create a session" do
    post login_url, params: { email: @user.email, password: "incorrect-password" }
    assert_response :unprocessable_entity
    assert_includes response.body, "E-posta veya şifre doğrulanamadı."

    post login_url, params: { email: "nobody@example.com", password: "correct-horse-battery" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "deactivated actors cannot sign in" do
    @user.actor.update!(active: false)
    post login_url, params: { email: @user.email, password: "correct-horse-battery" }

    assert_response :unprocessable_entity
    assert_nil session[:user_id]
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
      post login_url, params: { email: @user.email, password: "incorrect-password" }
      assert_response :unprocessable_entity
    end

    post login_url, params: { email: @user.email, password: "incorrect-password" }
    assert_response :too_many_requests
    assert_includes response.body, "Çok fazla giriş denemesi."
  end

  test "demo operator credentials are shown only when enabled" do
    get login_url
    assert_select ".login-demo-box code", text: User.demo_operator[:email]

    ENV["DEMO_OPERATOR_ENABLED"] = "false"
    get login_url
    assert_select ".login-demo-box", count: 0
  ensure
    ENV.delete("DEMO_OPERATOR_ENABLED")
  end
end
