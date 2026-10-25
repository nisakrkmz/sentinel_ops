require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "healthz is public and reports provider configuration without secrets" do
    get healthz_url

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "ok", body.fetch("status")
    assert_equal "disabled", body.dig("providers", "decision")
    assert_equal "disabled", body.dig("providers", "page_agent")
    assert body.fetch("knowledge_base").key?("indexed_articles")
    assert_no_match(/api_key|Bearer/i, response.body)
  end
end
