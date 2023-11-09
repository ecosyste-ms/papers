class CreateExports < ActiveRecord::Migration[7.1]
  def change
    create_table :exports do |t|
      t.string :date
      t.string :bucket_name
      t.integer :mentions_count

      t.timestamps
    end
  end
end
