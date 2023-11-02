class CreateProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :projects do |t|
      t.string :czi_id
      t.string :ecosystem
      t.string :name
      t.json :package
      t.integer :mentions_count

      t.timestamps
    end

    add_index :projects, [:ecosystem, :name]
  end
end
