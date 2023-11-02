class CreatePapers < ActiveRecord::Migration[7.1]
  def change
    create_table :papers do |t|
      t.string :doi, index: true
      t.string :openalex_id
      t.string :title
      t.datetime :publication_date
      t.json :openalex_data
      t.integer :mentions_count

      t.timestamps
    end
  end
end
