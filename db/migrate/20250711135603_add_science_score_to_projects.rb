class AddScienceScoreToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :science_score, :integer
    add_index :projects, :science_score
  end
end
