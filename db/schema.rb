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

ActiveRecord::Schema[7.2].define(version: 2026_08_30_101400) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "admins", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
  end

  create_table "boss_battles", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.datetime "started_at"
    t.datetime "ended_at"
    t.integer "attack_count", default: 0, null: false
    t.integer "hp", default: 120, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_critical_at"
    t.bigint "question_id", null: false
    t.index ["question_id"], name: "index_boss_battles_on_question_id"
    t.index ["team_id", "question_id"], name: "index_boss_battles_on_team_id_and_question_id", unique: true
    t.index ["team_id"], name: "index_boss_battles_on_team_id"
  end

  create_table "boss_readies", force: :cascade do |t|
    t.bigint "boss_battle_id", null: false
    t.bigint "player_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["boss_battle_id", "player_id"], name: "index_boss_readies_on_battle_and_player", unique: true
    t.index ["boss_battle_id"], name: "index_boss_readies_on_boss_battle_id"
    t.index ["player_id"], name: "index_boss_readies_on_player_id"
  end

  create_table "bosses", force: :cascade do |t|
    t.string "sprite", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sprite"], name: "index_bosses_on_sprite", unique: true
  end

  create_table "players", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.integer "role", null: false
    t.string "email", null: false
    t.integer "job"
    t.string "name"
    t.integer "gender", default: 0, null: false
    t.string "mobile"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "email"], name: "index_players_on_team_id_and_email", unique: true
    t.index ["team_id", "job"], name: "index_players_on_team_id_and_job", unique: true, where: "(job IS NOT NULL)"
    t.index ["team_id"], name: "index_players_on_team_id"
  end

  create_table "question_attempts", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.bigint "question_id", null: false
    t.datetime "started_at"
    t.datetime "ended_at"
    t.integer "hint_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_question_attempts_on_question_id"
    t.index ["team_id", "question_id"], name: "index_question_attempts_on_team_id_and_question_id", unique: true
    t.index ["team_id"], name: "index_question_attempts_on_team_id"
  end

  create_table "question_hints", force: :cascade do |t|
    t.bigint "question_id", null: false
    t.integer "position", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id", "position"], name: "index_question_hints_on_question_id_and_position", unique: true
    t.index ["question_id"], name: "index_question_hints_on_question_id"
  end

  create_table "questions", force: :cascade do |t|
    t.integer "number", null: false
    t.integer "kind", default: 1, null: false
    t.string "title", null: false
    t.string "answer_digest", null: false
    t.text "content"
    t.string "level"
    t.text "explanation"
    t.boolean "auto_start", default: false, null: false
    t.integer "base_score", default: 1000, null: false
    t.integer "puzzle_rows"
    t.integer "puzzle_cols"
    t.integer "boss_hp", default: 120, null: false
    t.integer "boss_time_limit", default: 30, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "boss_id", null: false
    t.integer "boss_phase"
    t.index ["boss_id"], name: "index_questions_on_boss_id"
    t.index ["number"], name: "index_questions_on_number", unique: true
  end

  create_table "reward_codes", force: :cascade do |t|
    t.string "code", null: false
    t.boolean "test_mode", default: false, null: false
    t.string "player_email"
    t.datetime "claimed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_reward_codes_on_code", unique: true
    t.index ["player_email"], name: "index_reward_codes_on_player_email"
  end

  create_table "score_entries", force: :cascade do |t|
    t.bigint "team_id", null: false
    t.integer "question_score", default: 0, null: false
    t.integer "time_score", default: 0, null: false
    t.integer "hint_score", default: 0, null: false
    t.integer "boss_score", default: 0, null: false
    t.integer "job_score", default: 0, null: false
    t.integer "total_score", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "question_id", null: false
    t.index ["question_id"], name: "index_score_entries_on_question_id"
    t.index ["team_id", "question_id"], name: "index_score_entries_on_team_id_and_question_id", unique: true
    t.index ["team_id"], name: "index_score_entries_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "serial_no", null: false
    t.boolean "test_mode", default: false, null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["serial_no"], name: "index_teams_on_serial_no", unique: true
  end

  add_foreign_key "boss_battles", "questions"
  add_foreign_key "boss_battles", "teams"
  add_foreign_key "boss_readies", "boss_battles"
  add_foreign_key "boss_readies", "players"
  add_foreign_key "players", "teams"
  add_foreign_key "question_attempts", "questions"
  add_foreign_key "question_attempts", "teams"
  add_foreign_key "question_hints", "questions"
  add_foreign_key "questions", "bosses"
  add_foreign_key "score_entries", "questions"
  add_foreign_key "score_entries", "teams"
end
