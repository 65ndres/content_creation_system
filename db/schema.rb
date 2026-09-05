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

ActiveRecord::Schema[7.2].define(version: 2026_09_05_021500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "cars2", id: false, force: :cascade do |t|
    t.string "brand", limit: 255
    t.string "model", limit: 255
    t.string "year", limit: 4
  end

  create_table "categories", primary_key: "category_id", id: :serial, force: :cascade do |t|
    t.string "category_name", limit: 255
    t.string "description", limit: 255
  end

  create_table "customers", primary_key: "customer_id", id: :serial, force: :cascade do |t|
    t.string "customer_name", limit: 255
    t.string "contact_name", limit: 255
    t.string "address", limit: 255
    t.string "city", limit: 255
    t.string "postal_code", limit: 255
    t.string "country", limit: 255
  end

  create_table "motos", id: false, force: :cascade do |t|
    t.string "brand", limit: 255
    t.string "model", limit: 255
    t.integer "year"
  end

  create_table "order_details", primary_key: "order_detail_id", id: :serial, force: :cascade do |t|
    t.integer "order_id"
    t.integer "product_id"
    t.integer "quantity"
  end

  create_table "orders", primary_key: "order_id", id: :serial, force: :cascade do |t|
    t.integer "customer_id"
    t.date "order_date"
  end

  create_table "products", primary_key: "product_id", id: :serial, force: :cascade do |t|
    t.string "product_name", limit: 255
    t.integer "category_id"
    t.string "unit", limit: 255
    t.decimal "price", precision: 10, scale: 2
  end

  create_table "scenes", force: :cascade do |t|
    t.text "text"
    t.jsonb "ai_image_prompt"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "story_id"
    t.jsonb "leonardo_gen_ids", default: []
    t.jsonb "images_data", default: []
    t.integer "images_total", default: 0
    t.string "video_gen_id"
    t.string "video_url"
    t.string "merged_audio_video_url"
    t.string "merged_audio_video_gen_id"
    t.string "leonardo_video_gen_id"
    t.string "leonardo_video_url"
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
    t.string "video_gen_id"
    t.string "video_url"
    t.jsonb "characters", default: [], null: false
    t.string "image_generation_model", default: "lucid", null: false
    t.string "image_generation_seed"
    t.index ["source_id"], name: "index_stories_on_source_id"
    t.index ["story_type_id"], name: "index_stories_on_story_type_id"
  end

  create_table "story_types", force: :cascade do |t|
    t.string "name", null: false
    t.text "story_prompt_text", null: false
    t.text "scenes_json_prompts", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "scene_text_min_chars", default: 70, null: false
    t.integer "scene_text_max_chars", default: 100, null: false
    t.integer "image_width", null: false
    t.integer "image_height", null: false
    t.integer "output_width", null: false
    t.integer "output_height", null: false
  end

  create_table "testproducts", primary_key: "testproduct_id", id: :serial, force: :cascade do |t|
    t.string "product_name", limit: 255
    t.integer "category_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "sources", "users"
  add_foreign_key "stories", "sources"
  add_foreign_key "stories", "story_types"
end
