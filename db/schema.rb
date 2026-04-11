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

ActiveRecord::Schema[8.2].define(version: 2026_04_11_133000) do
  create_table "authorized_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["email_address"], name: "index_authorized_users_on_email_address", unique: true
    t.index ["user_id"], name: "index_authorized_users_on_user_id"
  end

  create_table "bot_users", force: :cascade do |t|
    t.string "api_token"
    t.integer "authorized_user_id", null: false
    t.string "chat_id", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "linked_at"
    t.datetime "updated_at", null: false
    t.index ["api_token"], name: "index_bot_users_on_api_token", unique: true
    t.index ["authorized_user_id"], name: "index_bot_users_on_authorized_user_id"
    t.index ["chat_id", "code"], name: "index_bot_users_on_chat_id_and_code"
    t.index ["linked_at"], name: "index_bot_users_on_linked_at"
  end

  create_table "event_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.string "key"
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["event_id"], name: "index_event_tags_on_event_id"
  end

  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "environment"
    t.string "event_uuid"
    t.string "exception_message"
    t.string "exception_type"
    t.boolean "handled"
    t.integer "issue_id", null: false
    t.string "level"
    t.string "notification_reason"
    t.string "notification_state", default: "pending"
    t.datetime "notified_at"
    t.datetime "occurred_at"
    t.integer "project_id", null: false
    t.text "raw_json"
    t.string "release"
    t.string "server_name"
    t.string "transaction_name"
    t.datetime "updated_at", null: false
    t.index ["event_uuid"], name: "index_events_on_event_uuid"
    t.index ["issue_id"], name: "index_events_on_issue_id"
    t.index ["notification_reason"], name: "index_events_on_notification_reason"
    t.index ["notification_state"], name: "index_events_on_notification_state"
    t.index ["project_id"], name: "index_events_on_project_id"
  end

  create_table "issues", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "culprit"
    t.string "fingerprint_hash", null: false
    t.datetime "first_seen_at"
    t.string "last_environment"
    t.string "last_release"
    t.datetime "last_seen_at"
    t.string "level"
    t.integer "occurrences_count", default: 0
    t.string "platform"
    t.integer "project_id", null: false
    t.string "status", default: "open", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["fingerprint_hash"], name: "index_issues_on_fingerprint_hash"
    t.index ["project_id", "fingerprint_hash"], name: "index_issues_on_project_id_and_fingerprint_hash", unique: true
    t.index ["project_id"], name: "index_issues_on_project_id"
    t.index ["status"], name: "index_issues_on_status"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "default_environment"
    t.string "ingest_token", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["ingest_token"], name: "index_projects_on_ingest_token", unique: true
    t.index ["slug"], name: "index_projects_on_slug", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin"
    t.datetime "created_at", null: false
    t.string "email_address"
    t.string "first_name"
    t.string "image"
    t.string "last_name"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "authorized_users", "users"
  add_foreign_key "bot_users", "authorized_users"
  add_foreign_key "event_tags", "events"
  add_foreign_key "events", "issues"
  add_foreign_key "events", "projects"
  add_foreign_key "issues", "projects"
  add_foreign_key "sessions", "users"
end
