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

ActiveRecord::Schema[8.1].define(version: 2026_10_28_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "admin_access_events", force: :cascade do |t|
    t.bigint "actor_id", null: false
    t.bigint "admin_id", null: false
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_admin_access_events_on_actor_id"
    t.index ["admin_id"], name: "index_admin_access_events_on_admin_id"
  end

  create_table "admin_sessions", force: :cascade do |t|
    t.bigint "admin_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_admin_sessions_on_admin_id"
    t.index ["token_digest"], name: "index_admin_sessions_on_token_digest", unique: true
  end

  create_table "admins", force: :cascade do |t|
    t.string "email", null: false
    t.string "role", default: "admin", null: false
    t.string "google_uid"
    t.string "name"
    t.datetime "last_signed_in_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["google_uid"], name: "index_admins_on_google_uid", unique: true
    t.check_constraint "role::text = ANY (ARRAY['owner'::character varying, 'admin'::character varying]::text[])", name: "admin_roles"
  end

  add_foreign_key "admin_access_events", "admins"
  add_foreign_key "admin_access_events", "admins", column: "actor_id"
  add_foreign_key "admin_sessions", "admins"
end
