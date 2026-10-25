require "test_helper"

class CopilotLayoutTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_nisa }

  test "copilot is a floating launcher with an honest disabled state instead of a header button" do
    get root_url

    assert_select "#sentinel-copilot[data-turbo-permanent][data-copilot-enabled='false']"
    assert_select "#sentinel-copilot button.copilot-fab[aria-controls='copilot-panel'][aria-expanded='false']"
    assert_select "#copilot-panel[hidden]"
    assert_select "#sentinel-copilot textarea[disabled]"
    assert_select "[data-page-agent-launch]", count: 0
    assert_select ".enterprise-header", text: /Page Agent/, count: 0
  end

  test "new incident navigation is exposed to the agent allowlist" do
    get root_url

    assert_select "a[data-agent-id='new-incident']"
    assert_select "a[data-agent-id='header-new-incident']"
    assert_select "a[data-agent-id='handoff-queue-navigation']"
  end

  test "new incident form does not show the copilot hint when the copilot is unavailable" do
    get new_incident_url

    assert_select "[data-copilot-hint]", count: 0
  end
end
