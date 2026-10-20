require "test_helper"

class PageAgentProxyTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body) do
    def read_body
      yield body
    end
  end

  class FakeHttpClient
    attr_reader :captured_request

    def initialize(response)
      @response = response
    end

    def start(*_arguments, **_options)
      yield self
    end

    def request(request)
      @captured_request = request
      yield @response
      @response
    end
  end

  setup do
    @original_environment = %w[
      PAGE_AGENT_API_KEY PAGE_AGENT_BASE_URL PAGE_AGENT_MODEL PAGE_AGENT_ALLOWED_MODELS
    ].to_h { |key| [ key, ENV[key] ] }
    ENV["PAGE_AGENT_API_KEY"] = "server-only-provider-secret"
    ENV["PAGE_AGENT_BASE_URL"] = "https://llm.example.test/v1"
    ENV["PAGE_AGENT_MODEL"] = "approved-model"
    ENV["PAGE_AGENT_ALLOWED_MODELS"] = "approved-model,second-approved-model"
    Incident.create!(
      short_description: "Caller privacy test",
      service_affected: "Global VPN Gateway",
      requested_by: "Sarah Jenkins (Finance VP)"
    )
  end

  teardown do
    @original_environment.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  test "forwards only to the configured provider and redacts caller, email, and phone data" do
    fake_http = FakeHttpClient.new(
      FakeResponse.new(
        "200",
        JSON.generate(choices: [ { message: { role: "assistant", tool_calls: [] } } ])
      )
    )
    result = PageAgentProxy.call(
      {
        "model" => "approved-model",
        "messages" => [
          {
            "role" => "user",
            "content" => "Sarah Jenkins (Finance VP) called at sarah@example.com, phone 555-123-4567."
          }
        ],
        "stream" => true,
        "max_tokens" => 20_000
      },
      http_client: fake_http
    )

    captured_request = fake_http.captured_request
    forwarded = JSON.parse(captured_request.body)
    assert_equal 200, result.status
    assert_equal "application/json", captured_request["Content-Type"]
    assert_equal "Bearer server-only-provider-secret", captured_request["Authorization"]
    assert_equal "https://llm.example.test/v1/chat/completions", captured_request.uri.to_s
    assert_equal "approved-model", forwarded["model"]
    assert_equal false, forwarded["stream"]
    assert_equal PageAgentProxy::MAX_COMPLETION_TOKENS, forwarded["max_tokens"]
    assert_includes forwarded.dig("messages", 0, "content"), "[REDACTED_CALLER]"
    assert_includes forwarded.dig("messages", 0, "content"), "[REDACTED_EMAIL]"
    assert_includes forwarded.dig("messages", 0, "content"), "[REDACTED_PHONE]"
    refute_includes captured_request.body, "Sarah Jenkins"
    refute_includes captured_request.body, "sarah@example.com"
    refute_includes captured_request.body, "555-123-4567"
    assert_equal "server-only-provider-secret", ENV["PAGE_AGENT_API_KEY"]
  end

  test "is disabled unless the configured model is explicitly allowlisted" do
    assert PageAgentProxy.configured?

    ENV["PAGE_AGENT_MODEL"] = "unapproved-model"

    assert_not PageAgentProxy.configured?
    assert_nil PageAgentProxy.public_model
  end
end
