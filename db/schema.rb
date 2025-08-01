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

ActiveRecord::Schema[8.0].define(version: 2025_07_11_135603) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "exports", force: :cascade do |t|
    t.string "date"
    t.string "bucket_name"
    t.integer "mentions_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "mentions", force: :cascade do |t|
    t.integer "paper_id"
    t.integer "project_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["paper_id"], name: "index_mentions_on_paper_id"
    t.index ["project_id"], name: "index_mentions_on_project_id"
  end

  create_table "papers", force: :cascade do |t|
    t.string "doi"
    t.string "openalex_id"
    t.string "title"
    t.datetime "publication_date"
    t.json "openalex_data"
    t.integer "mentions_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_synced_at"
    t.text "urls", default: [], array: true
    t.index ["doi"], name: "index_papers_on_doi"
  end

  create_table "projects", force: :cascade do |t|
    t.string "czi_id"
    t.string "ecosystem"
    t.string "name"
    t.json "package"
    t.integer "mentions_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_synced_at"
    t.json "commits_data"
    t.text "readme_content"
    t.json "educational_commit_emails"
    t.integer "science_score"
    t.index ["ecosystem", "name"], name: "index_projects_on_ecosystem_and_name"
    t.index ["science_score"], name: "index_projects_on_science_score"
  end
end
