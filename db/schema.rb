# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_25_140000) do
  create_table "actors", force: :cascade do |t|
    t.string "kind", null: false
    t.string "name", null: false
    t.string "owner"
    t.json "scopes", default: [], null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind", "name"], name: "index_actors_on_kind_and_name", unique: true
  end

  create_table "api_tokens", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.string "token_digest", null: false
    t.json "scopes", default: [], null: false
    t.datetime "last_used_at"
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_api_tokens_on_actor_id"
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
  end

  create_table "decisions", force: :cascade do |t|
    t.integer "incident_id", null: false
    t.integer "actor_id"
    t.string "kind", null: false
    t.string "provider", null: false
    t.string "model"
    t.string "prompt_version"
    t.string "input_digest"
    t.json "output_json", default: {}, null: false
    t.float "confidence"
    t.integer "latency_ms"
    t.float "cost_estimate"
    t.json "sources", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "completed", null: false
    t.string "error_code"
    t.index ["actor_id"], name: "index_decisions_on_actor_id"
    t.index ["incident_id"], name: "index_decisions_on_incident_id"
  end

  create_table "handoffs", force: :cascade do |t|
    t.integer "incident_id", null: false
    t.integer "from_actor_id", null: false
    t.string "to_actor_or_group", null: false
    t.string "reason_code", null: false
    t.float "confidence"
    t.json "brief", default: {}, null: false
    t.string "status", default: "open", null: false
    t.integer "resolved_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_actor_id"], name: "index_handoffs_on_from_actor_id"
    t.index ["incident_id"], name: "index_handoffs_on_incident_id"
    t.index ["resolved_by_id"], name: "index_handoffs_on_resolved_by_id"
  end

  create_table "incidents", force: :cascade do |t|
    t.string "title"
    t.string "service_name"
    t.integer "severity"
    t.integer "status"
    t.text "error_message"
    t.text "stack_trace"
    t.string "error_signature"
    t.datetime "sla_deadline"
    t.datetime "sla_breached_at"
    t.datetime "investigating_at"
    t.datetime "resolved_at"
    t.text "root_cause_analysis"
    t.text "resolution_steps"
    t.string "assigned_to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "number"
    t.string "caller_id"
    t.string "requested_by"
    t.string "short_description"
    t.text "description"
    t.string "service_affected"
    t.integer "priority", default: 2
    t.integer "state", default: 0
    t.integer "sla_status", default: 0
    t.string "category", default: "Enterprise Software"
    t.string "assignment_group", default: "ITSM Platform Operations"
    t.text "resolution_notes"
    t.string "on_hold_reason"
    t.integer "opened_by_actor_id"
    t.string "origin", default: "ui", null: false
    t.string "triage_status", default: "pending", null: false
    t.string "idempotency_key"
    t.string "idempotency_request_digest"
    t.index ["idempotency_key"], name: "index_incidents_on_idempotency_key", unique: true
    t.index ["idempotency_request_digest"], name: "index_incidents_on_idempotency_request_digest"
    t.index ["number"], name: "index_incidents_on_number", unique: true
    t.index ["opened_by_actor_id"], name: "index_incidents_on_opened_by_actor_id"
  end

  create_table "kb_candidates", force: :cascade do |t|
    t.integer "incident_id", null: false
    t.integer "submitted_by_id", null: false
    t.integer "reviewed_by_id"
    t.integer "knowledge_article_id"
    t.string "status", default: "pending", null: false
    t.text "root_cause", null: false
    t.json "resolution_steps", default: [], null: false
    t.text "verification", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["incident_id", "status"], name: "index_kb_candidates_on_incident_id_and_status"
    t.index ["incident_id"], name: "index_kb_candidates_on_incident_id"
    t.index ["knowledge_article_id"], name: "index_kb_candidates_on_knowledge_article_id"
    t.index ["reviewed_by_id"], name: "index_kb_candidates_on_reviewed_by_id"
    t.index ["submitted_by_id"], name: "index_kb_candidates_on_submitted_by_id"
  end

  create_table "knowledge_articles", force: :cascade do |t|
    t.string "slug", null: false
    t.string "title", null: false
    t.string "affected_service", null: false
    t.string "category", null: false
    t.string "source", null: false
    t.string "configuration_item"
    t.string "version"
    t.text "symptoms", null: false
    t.text "root_cause", null: false
    t.json "resolution_steps", default: [], null: false
    t.text "verification", null: false
    t.boolean "approved", default: false, null: false
    t.integer "source_incident_id"
    t.datetime "indexed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved", "affected_service"], name: "index_knowledge_articles_on_approved_and_affected_service"
    t.index ["slug"], name: "index_knowledge_articles_on_slug", unique: true
    t.index ["source_incident_id"], name: "index_knowledge_articles_on_source_incident_id", unique: true
  end

  create_table "knowledge_chunks", force: :cascade do |t|
    t.integer "knowledge_article_id", null: false
    t.string "chunk_id", null: false
    t.string "section", null: false
    t.text "content", null: false
    t.json "embedding"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "embedding_provider"
    t.string "embedding_model"
    t.string "embedding_content_digest"
    t.index ["chunk_id"], name: "index_knowledge_chunks_on_chunk_id", unique: true
    t.index ["embedding_provider", "embedding_model"], name: "idx_on_embedding_provider_embedding_model_879b29c36d"
    t.index ["knowledge_article_id"], name: "index_knowledge_chunks_on_knowledge_article_id"
  end

  create_table "timeline_events", force: :cascade do |t|
    t.integer "incident_id", null: false
    t.string "event_type"
    t.text "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "actor_id"
    t.index ["actor_id"], name: "index_timeline_events_on_actor_id"
    t.index ["incident_id"], name: "index_timeline_events_on_incident_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.integer "actor_id", null: false
    t.datetime "last_sign_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_users_on_actor_id", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "api_tokens", "actors"
  add_foreign_key "decisions", "actors"
  add_foreign_key "decisions", "incidents"
  add_foreign_key "handoffs", "actors", column: "from_actor_id"
  add_foreign_key "handoffs", "actors", column: "resolved_by_id"
  add_foreign_key "handoffs", "incidents"
  add_foreign_key "incidents", "actors", column: "opened_by_actor_id"
  add_foreign_key "kb_candidates", "actors", column: "reviewed_by_id"
  add_foreign_key "kb_candidates", "actors", column: "submitted_by_id"
  add_foreign_key "kb_candidates", "incidents", on_delete: :cascade
  add_foreign_key "kb_candidates", "knowledge_articles"
  add_foreign_key "knowledge_articles", "incidents", column: "source_incident_id", on_delete: :nullify
  add_foreign_key "knowledge_chunks", "knowledge_articles"
  add_foreign_key "timeline_events", "actors"
  add_foreign_key "timeline_events", "incidents"
  add_foreign_key "users", "actors"
end
