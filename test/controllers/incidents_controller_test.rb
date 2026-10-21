require "test_helper"

class IncidentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as_nisa
    @incident = Incident.create!(
      short_description: "SAP ERP S/4HANA Background Batch Pool Exhaustion",
      service_affected: "SAP ERP",
      priority: :p1_critical,
      requested_by: "Sarah Jenkins (Finance VP)",
      category: "Enterprise Software"
    )
  end

  test "should get index" do
    get root_url
    assert_response :success
    assert_select "h1", /ITSM Incident Management|SentinelOps/
    assert_no_match(/ServiceNow|G2|Capterra/i, response.body)
  end

  test "should get new" do
    get new_incident_url
    assert_response :success
    assert_select "form"
    assert_no_match(/ServiceNow|G2|Capterra/i, response.body)
  end

  test "should create incident with servicenow fields" do
    assert_difference("Incident.count") do
      post incidents_url, params: {
        incident: {
          short_description: "Active Directory SSO Kerberos Clock Skew",
          service_affected: "Active Directory SSO",
          priority: "p2_high",
          category: "Identity & Security",
          requested_by: "Elena Rostova (Security Operations)",
          description: "Kerberos authentication failure across regional domain controllers"
        }
      }
    end

    new_inc = Incident.last
    assert_redirected_to incident_url(new_inc)
    assert_match(/\AINC\d{6}\z/, new_inc.number)
    assert_equal "Active Directory SSO", new_inc.service_affected
    assert_equal "new_ticket", new_inc.state
    assert_equal "human", new_inc.opened_by_actor.kind
    assert_equal "Nisa", new_inc.opened_by_actor.name
    assert_equal new_inc.opened_by_actor_id, new_inc.timeline_events.first.actor_id
    assert_equal "pending", new_inc.triage_status
    assert_equal "failed", new_inc.decisions.triage.first.status
    assert_equal "provider_not_configured", new_inc.decisions.triage.first.error_code
    assert_equal "provider_unavailable", new_inc.decisions.route.first.output_json["reason_code"]
    assert_equal "provider_unavailable", new_inc.handoffs.open.sole.reason_code
  end

  test "should show incident" do
    get incident_url(@incident)
    assert_response :success
    assert_includes response.body, @incident.number
    assert_includes response.body, @incident.short_description
    assert_no_match(/ServiceNow|G2|Capterra/i, response.body)
  end

  test "should transition state to in_progress" do
    post start_progress_incident_url(@incident), params: { assignee: "Can Korkmaz (Senior ITSM Lead)" }
    assert_redirected_to incident_url(@incident)
    assert_equal "in_progress", @incident.reload.state
    assert_equal "Can Korkmaz (Senior ITSM Lead)", @incident.assigned_to
  end

  test "should transition state to on_hold" do
    @incident.update!(state: :in_progress)
    post put_on_hold_incident_url(@incident), params: { on_hold_reason: "Vendor SAP ticket response pending" }
    assert_redirected_to incident_url(@incident)
    assert_equal "on_hold", @incident.reload.state
    assert_equal "Vendor SAP ticket response pending", @incident.on_hold_reason
  end

  test "should transition state to resolved" do
    @incident.update!(state: :in_progress)

    post resolve_incident_url(@incident), params: {
      root_cause_analysis: "SAP work process exhaustion due to batch schedule overlap",
      resolution_notes: "SM50 work processes increased to 36 and jobs staggered",
      verification: "RFC test passed and the queue returned to normal"
    }

    assert_redirected_to incident_url(@incident)
    assert_equal "resolved", @incident.reload.state
    assert_equal "SM50 work processes increased to 36 and jobs staggered", @incident.resolution_notes
    candidate = @incident.kb_candidates.sole
    assert_equal "pending", candidate.status
    assert_equal "RFC test passed and the queue returned to normal", candidate.verification
    assert_nil candidate.knowledge_article
  end

  test "should check sla and report status" do
    post check_sla_incident_url(@incident)
    assert_redirected_to incident_url(@incident)
  end

  test "should trigger simulation scenario" do
    assert_difference("Incident.count") do
      post simulate_incidents_url, params: { scenario: "vpn_gateway" }
    end

    simulated = Incident.last
    assert_redirected_to incident_url(simulated)
    assert_equal "Global VPN Gateway", simulated.service_affected
    assert_equal "simulation", simulated.origin
    assert_equal "agent", simulated.opened_by_actor.kind
    assert_equal "SentinelOps Monitoring Agent", simulated.opened_by_actor.name
    assert_equal "provider_unavailable", simulated.handoffs.open.sole.reason_code

    get incident_url(simulated)
    assert_response :success
    assert_includes response.body, "SİMÜLASYON"
    assert_includes response.body, "Agent Run Trace"
    assert_includes response.body, "Onay kuyruğunda incele"
  end

  test "shows an agent run trace even when no provider is configured" do
    @incident.update!(triage_status: "pending")
    failed_triage = @incident.decisions.create!(
      kind: :triage,
      provider: "unconfigured",
      output_json: {},
      status: :failed,
      error_code: "provider_not_configured"
    )
    policy = @incident.decisions.create!(
      kind: :route,
      provider: "hitl-policy",
      output_json: { "action" => "handoff", "reason_code" => "provider_unavailable" }
    )
    @incident.handoffs.create!(
      from_actor: Actor.find_or_create_by!(kind: :agent, name: "Trace Test Agent"),
      to_actor_or_group: "Service Desk",
      reason_code: "provider_unavailable",
      brief: { "summary" => @incident.short_description }
    )

    get incident_url(@incident)

    assert_response :success
    assert_includes response.body, failed_triage.provider
    assert_includes response.body, policy.output_json["action"]
    assert_includes response.body, "Agent Run Trace"
  end
end
