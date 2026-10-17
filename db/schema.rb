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

ActiveRecord::Schema[8.1].define(version: 2026_10_16_113318) do
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
    t.index ["number"], name: "index_incidents_on_number", unique: true
  end

  create_table "timeline_events", force: :cascade do |t|
    t.integer "incident_id", null: false
    t.string "event_type"
    t.text "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["incident_id"], name: "index_timeline_events_on_incident_id"
  end

  add_foreign_key "timeline_events", "incidents"
end
