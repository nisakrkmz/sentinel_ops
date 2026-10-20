require "test_helper"

module Api
  module V1
    class IncidentsControllerTest < ActionDispatch::IntegrationTest
      SCOPES = %w[
        incidents:create incidents:read incidents:comment incidents:claim
        incidents:resolve handoff:create kb:read events:read
      ].freeze

      setup do
        @previous_cache_store = Rails.cache
        Rails.cache = ActiveSupport::Cache::MemoryStore.new
        @original_environment = %w[
          AGENT_TOKEN_PEPPER DECISION_PROVIDER DECISION_API_KEY DECISION_MODEL DECISION_BASE_URL
          EMBEDDING_PROVIDER EMBEDDING_API_KEY EMBEDDING_MODEL EMBEDDING_BASE_URL
          LLM_PROVIDER LLM_API_KEY LLM_MODEL LLM_BASE_URL
        ].to_h { |key| [ key, ENV[key] ] }
        ENV["AGENT_TOKEN_PEPPER"] = "test-api-pepper"
        %w[
          DECISION_PROVIDER DECISION_API_KEY DECISION_MODEL DECISION_BASE_URL
          EMBEDDING_PROVIDER EMBEDDING_API_KEY EMBEDDING_MODEL EMBEDDING_BASE_URL
          LLM_PROVIDER LLM_API_KEY LLM_MODEL LLM_BASE_URL
        ].each { |key| ENV.delete(key) }
        @actor = Actor.create!(
          kind: :agent,
          name: "REST Test Agent #{SecureRandom.hex(4)}",
          owner: "test",
          scopes: SCOPES
        )
        @token = ApiToken.issue!(actor: @actor, scopes: SCOPES, pepper: "test-api-pepper")
        @headers = {
          "Authorization" => "Bearer #{@token.plaintext_token}",
          "Accept" => "application/json"
        }
      end

      teardown do
        @original_environment.each do |key, value|
          value.nil? ? ENV.delete(key) : ENV[key] = value
        end
        Rails.cache = @previous_cache_store
      end

      test "rejects missing credentials with a machine-readable error" do
        get api_v1_incidents_url

        assert_response :unauthorized
        assert_equal "unauthorized", response.parsed_body.fetch("code")
        assert_equal false, response.parsed_body.fetch("retryable")
        assert_equal({}, response.parsed_body.fetch("field_errors"))
      end

      test "enforces actor scopes" do
        limited = ApiToken.issue!(actor: @actor, scopes: [ "incidents:create" ], pepper: "test-api-pepper")
        headers = @headers.merge("Authorization" => "Bearer #{limited.plaintext_token}")

        get api_v1_incidents_url, headers: headers

        assert_response :forbidden
        assert_equal "insufficient_scope", response.parsed_body.fetch("code")
      end

      test "creates once for an idempotency key and rejects a changed payload" do
        payload = {
          short_description: "Database pool exhausted",
          description: "Checkout requests are timing out.",
          service_affected: "Payment Gateway",
          category: "Cloud Infrastructure"
        }
        headers = @headers.merge("Idempotency-Key" => "payment-alert-001")
        post api_v1_incidents_url, params: payload, headers: headers, as: :json
        assert_response :created
        incident_number = response.parsed_body.dig("data", "number")
        assert_equal "pending", response.parsed_body.dig("data", "triage_status")
        incident = Incident.find_by!(idempotency_key: "payment-alert-001")
        assert_equal "provider_unavailable", incident.decisions.route.first.output_json["reason_code"]
        assert_equal "provider_unavailable", incident.handoffs.open.sole.reason_code

        post api_v1_incidents_url, params: payload, headers: headers, as: :json
        assert_response :ok
        assert_equal true, response.parsed_body.fetch("idempotent_replay")
        assert_equal incident_number, response.parsed_body.dig("data", "number")

        post api_v1_incidents_url,
          params: payload.merge(short_description: "Different incident"),
          headers: headers,
          as: :json
        assert_response :conflict
        assert_equal "idempotency_key_reused", response.parsed_body.fetch("code")

        assert_equal 1, Incident.where(idempotency_key: "payment-alert-001").count
        assert_equal 1, incident.decisions.triage.count
        assert_equal "api", Incident.find_by!(idempotency_key: "payment-alert-001").origin
        assert_equal @actor.id, Incident.find_by!(idempotency_key: "payment-alert-001").opened_by_actor_id
        assert_equal @actor.name, Incident.find_by!(idempotency_key: "payment-alert-001").requested_by
      end

      test "requires Idempotency-Key and returns validation field errors" do
        post api_v1_incidents_url,
          params: { short_description: "Missing service" },
          headers: @headers,
          as: :json

        assert_response :bad_request
        assert_equal "idempotency_key_required", response.parsed_body.fetch("code")

        post api_v1_incidents_url,
          params: { short_description: "Missing service" },
          headers: @headers.merge("Idempotency-Key" => "missing-service"),
          as: :json

        assert_response :unprocessable_entity
        assert response.parsed_body.fetch("field_errors").key?("service_affected")
      end

      test "lists incidents with filters, cursors, and rate limit headers" do
        older = create_incident("Older API incident", created_at: 2.minutes.ago, state: :in_progress, priority: :p1_critical)
        newer = create_incident("Newer API incident", created_at: 1.minute.ago, state: :in_progress, priority: :p1_critical)
        create_incident("Other service", created_at: 30.seconds.ago, state: :new_ticket, service_affected: "SAP ERP")

        get api_v1_incidents_url,
          params: { state: "in_progress", priority: "P1", service: "Payment Gateway", limit: 1 },
          headers: @headers

        assert_response :success
        assert_equal "120", response.headers.fetch("X-RateLimit-Limit")
        assert_operator response.headers.fetch("X-RateLimit-Remaining").to_i, :<, 120
        assert_equal [ newer.number ], response.parsed_body.fetch("data").map { |item| item.fetch("number") }
        cursor = response.parsed_body.fetch("next_cursor")
        assert cursor.present?

        get api_v1_incidents_url, params: { cursor: cursor, limit: 1 }, headers: @headers

        assert_response :success
        assert_equal [ older.number ], response.parsed_body.fetch("data").map { |item| item.fetch("number") }
      end

      test "gets incidents by number and rejects malformed cursors" do
        incident = create_incident("Readable API incident")

        get api_v1_incident_url(incident.number), headers: @headers

        assert_response :success
        assert_equal incident.number, response.parsed_body.dig("data", "number")

        get api_v1_incidents_url, params: { cursor: "not-a-cursor" }, headers: @headers

        assert_response :bad_request
        assert_equal "invalid_cursor", response.parsed_body.fetch("code")
      end

      test "knowledge search reports provider unavailability instead of returning fabricated results" do
        get api_v1_kb_search_url, params: { q: "VPN address pool" }, headers: @headers

        assert_response :service_unavailable
        assert_equal "embedding_provider_not_configured", response.parsed_body.fetch("code")
        assert_equal true, response.parsed_body.fetch("retryable")
      end

      test "streams incident timeline events as SSE from the supplied cursor" do
        incident = create_incident("SSE cursor test")
        event = incident.timeline_events.create!(
          actor: @actor,
          event_type: "comment",
          message: "Status update"
        )

        get api_v1_events_url, headers: @headers.merge("Last-Event-ID" => "0")

        assert_response :success
        assert_includes response.media_type, "text/event-stream"
        assert_includes response.body, "id: #{event.id}"
        assert_includes response.body, incident.number

        get api_v1_events_url, headers: @headers.merge("Last-Event-ID" => event.id.to_s)

        assert_response :success
        assert_not_includes response.body, "id: #{event.id}\n"
      end

      test "supports comments and first-owner claims with actor attribution" do
        incident = create_incident("Agent claim test", assigned_to: nil)

        post comments_api_v1_incident_url(incident), params: { content: "Checked the alert source." }, headers: @headers, as: :json

        assert_response :created
        assert_equal @actor.name, response.parsed_body.dig("data", "actor")
        event = incident.timeline_events.find_by!(event_type: "comment")
        assert_equal @actor.id, event.actor_id

        post claim_api_v1_incident_url(incident), headers: @headers, as: :json

        assert_response :success
        assert_equal @actor.name, incident.reload.assigned_to
        assert_equal @actor.id, incident.timeline_events.find_by!(event_type: "claimed").actor_id
      end

      test "creates scoped handoffs with a structured brief" do
        incident = create_incident("Needs human review")

        post handoff_api_v1_incident_url(incident),
          params: {
            reason_code: "low_confidence",
            to_actor_or_group: "Network Operations",
            confidence: 0.42,
            brief: { summary: "VPN pool alert", next_step: "Check address utilization" }
          },
          headers: @headers,
          as: :json

        assert_response :created
        handoff = incident.handoffs.sole
        assert_equal @actor, handoff.from_actor
        assert_equal "Network Operations", handoff.to_actor_or_group
        assert_equal "needs_human", incident.reload.triage_status
      end

      test "resolves with only approved knowledge citations" do
        incident = create_incident("Grounded resolution test")
        article = KnowledgeArticle.create!(
          slug: "api-test-approved-memory",
          title: "Approved API test memory",
          affected_service: "Payment Gateway",
          category: "Cloud Infrastructure",
          source: "synthetic_seed",
          symptoms: "Database pool saturation.",
          root_cause: "The pool was below demand.",
          resolution_steps: [ "Review pool utilization." ],
          verification: "A test checkout succeeds.",
          approved: true
        )
        article.rebuild_chunks!
        citation = article.knowledge_chunks.first.chunk_id

        post resolve_api_v1_incident_url(incident),
          params: {
            resolution_notes: "Increase capacity after approval.",
            root_cause: "The database pool was saturated.",
            verification: "A test checkout completes successfully.",
            citations: [ citation ]
          },
          headers: @headers,
          as: :json

        assert_response :success
        assert_equal "resolved", incident.reload.state
        assert_equal "pending", incident.kb_candidates.sole.status

        another_incident = create_incident("Invalid citation test")
        post resolve_api_v1_incident_url(another_incident),
          params: {
            resolution_notes: "Close with an unknown source.",
            root_cause: "Unknown",
            citations: [ "not-a-known-chunk" ]
          },
          headers: @headers,
          as: :json

        assert_response :unprocessable_entity
        assert_equal "invalid_citations", response.parsed_body.fetch("code")
        assert_not another_incident.reload.resolved?
      end

      test "serves OpenAPI, llms.txt, and agent card without a token" do
        get "/api/v1/openapi.json"
        assert_response :success
        assert_equal "3.1.0", response.parsed_body.fetch("openapi")

        get "/.well-known/agent-card.json"
        assert_response :success
        assert_equal "SentinelOps", response.parsed_body.fetch("name")

        get "/llms.txt"
        assert_response :success
        assert_includes response.body, "/api/v1/openapi.json"
      end

      private

      def create_incident(description, created_at: Time.current, state: :new_ticket, priority: :p3_moderate, service_affected: "Payment Gateway", assigned_to: "ITSM Triage Queue")
        Incident.create!(
          short_description: description,
          description: "Integration test incident.",
          service_affected: service_affected,
          category: "Cloud Infrastructure",
          opened_by_actor: @actor,
          assigned_to: assigned_to,
          state: state,
          priority: priority,
          created_at: created_at
        )
      end
    end
  end
end
