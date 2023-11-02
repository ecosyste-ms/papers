class CreateMentions < ActiveRecord::Migration[7.1]
  def change
    create_table :mentions do |t|
      t.integer :paper_id, index: true
      t.integer :project_id, index: true

      t.timestamps
    end
  end
end
