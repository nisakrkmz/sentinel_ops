require "test_helper"

class PageAgentProxyControllerTest < ActionDispatch::IntegrationTest
  PATH = "/page-agent/v1/chat/completions"

  setup do
    @previous_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @original_environment = %w[
      PAGE_AGENT_API_KEY PAGE_AGENT_BASE_URL PAGE_AGENT_MODEL PAGE_AGENT_ALLOWED_MODELS
    ].to_h { |key| [ key, ENV[key] ] }
    ENV["PAGE_AGENT_API_KEY"] = "test-server-key"
    ENV["PAGE_AGENT_BASE_URL"] = "https://llm.example.test/v1"
    ENV["PAGE_AGENT_MODEL"] = "approved-model"
    ENV["PAGE_AGENT_ALLOWED_MODELS"] = "approved-model"
    sign_in_as_nisa
    @headers = { "Origin" => "http://www.example.com" }
    @payload = {
      model: "approved-model",
      messages: [ { role: "user", content: "Search the visible incidents." } ],
      tools: []
    }
  end

  teardown do
    @original_environment.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    Rails.cache = @previous_cache_store
  end

  test "returns a truthful disabled response when server provider configuration is absent" do
    ENV.delete("PAGE_AGENT_API_KEY")
    post PATH, params: @payload, headers: @headers, as: :json

    assert_response :service_unavailable
    assert_equal "provider_not_configured", response.parsed_body.dig("error", "code")
  end

  test "renders the pinned auto-init-disabled bundle only when server proxy config is valid" do
    get "/"

    assert_response :success
    assert_includes response.body, 'name="page-agent-model" content="approved-model"'
    assert_includes response.body, "/vendor/page-agent-1.12.4.js?autoInit=false"
    refute_includes response.body, "test-server-key"
    assert_select "button[data-agent-id='corporate-simulation'][data-agent-confirm]"

    get new_incident_path

    assert_response :success
    assert_select "[data-copilot-hint]", count: 0
    assert_select ".copilot-banner:not(.is-disabled)", text: /Page Agent sizin için şunları yapabilir/
    assert_select ".copilot-banner button[data-copilot-suggestion]:not([disabled])", minimum: 3
    assert_select "#sentinel-copilot[data-copilot-enabled='true'] button.copilot-fab:not([disabled])", text: /Page Agent Copilot/
  end

  test "rejects cross-origin requests and models outside the configured allowlist" do
    post PATH,
      params: @payload,
      headers: @headers.merge("Origin" => "https://attacker.example"),
      as: :json

    assert_response :forbidden
    assert_equal "same_origin_request_required", response.parsed_body.dig("error", "code")

    post PATH,
      params: @payload.merge(model: "unapproved-model"),
      headers: @headers,
      as: :json

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.dig("error", "code")
  end

  test "limits proxy traffic per source and returns a retry interval" do
    invalid_payload = @payload.merge(messages: [])
    PageAgentProxyController::RATE_LIMIT.times do
      post PATH, params: invalid_payload, headers: @headers, as: :json
      assert_response :bad_request
    end

    post PATH, params: invalid_payload, headers: @headers, as: :json
    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
    assert_equal "rate_limit_exceeded", response.parsed_body.dig("error", "code")
  end

  test "rejects oversized and malformed request bodies" do
    post PATH,
      params: " " * (PageAgentProxy::MAX_REQUEST_BYTES + 1),
      headers: @headers.merge("CONTENT_TYPE" => "application/json")

    assert_response :content_too_large
    assert_equal "request_too_large", response.parsed_body.dig("error", "code")

    post PATH,
      params: "{",
      headers: @headers.merge("CONTENT_TYPE" => "application/json")

    assert_response :bad_request
    assert_equal "invalid_json", response.parsed_body.dig("error", "code")
  end
end
