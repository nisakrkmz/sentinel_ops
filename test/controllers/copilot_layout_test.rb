require "test_helper"

class CopilotLayoutTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_nisa }

  test "copilot is a labelled bottom-right launcher with an honest disabled state instead of a header button" do
    get root_url

    assert_select "#sentinel-copilot[data-turbo-permanent][data-copilot-enabled='false']"
    assert_select "#sentinel-copilot button.copilot-fab[disabled]", text: /Page Agent/
    assert_select "[data-page-agent-launch]", count: 0
    assert_select ".enterprise-header", text: /Page Agent/, count: 0
  end

  test "new incident navigation is exposed to the agent allowlist" do
    get root_url

    assert_select "a[data-agent-id='new-incident']"
    assert_select "a[data-agent-id='header-new-incident']"
    assert_select "a[data-agent-id='handoff-queue-navigation']"
  end

  test "every workspace page shows the Page Agent capability banner, honestly disabled without a provider" do
    [ root_url, new_incident_url, knowledge_articles_url, handoffs_url ].each do |url|
      get url

      assert_select ".copilot-banner.is-disabled", text: /Page Agent sizin için şunları yapabilir/
      assert_select ".copilot-banner button[data-copilot-suggestion][disabled]", minimum: 3
    end
    assert_select "[data-copilot-hint]", count: 0
  end
end
