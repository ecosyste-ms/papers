class AddCommitAndReadmeDataToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :commits_data, :json
    add_column :projects, :readme_content, :text
    add_column :projects, :educational_commit_emails, :json
  end
end
