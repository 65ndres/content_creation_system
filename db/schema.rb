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

ActiveRecord::Schema[7.2].define(version: 2024_09_02_094257) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "scenes", force: :cascade do |t|
    t.text "text"
    t.jsonb "ai_image_prompt"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "story_id"
    t.jsonb "leonardo_gen_ids", default: []
    t.jsonb "images_data", default: []
    t.integer "images_total", default: 0
  end

  create_table "sources", force: :cascade do |t|
    t.text "text"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sources_on_user_id"
  end

  create_table "stories", force: :cascade do |t|
    t.text "text"
    t.bigint "source_id", null: false
    t.bigint "story_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_id"], name: "index_stories_on_source_id"
    t.index ["story_type_id"], name: "index_stories_on_story_type_id"
  end

  create_table "story_types", force: :cascade do |t|
    t.string "name", null: false
    t.text "story_prompt_text", null: false
    t.text "scenes_json_prompts", null: false
    t.integer "output_width", null: false
    t.integer "output_height", null: false
    t.integer "image_width", null: false
    t.integer "image_height", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "sources", "users"
  add_foreign_key "stories", "sources"
  add_foreign_key "stories", "story_types"
end
