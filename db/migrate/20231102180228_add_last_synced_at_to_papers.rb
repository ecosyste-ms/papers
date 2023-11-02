class AddLastSyncedAtToPapers < ActiveRecord::Migration[7.1]
  def change
    add_column :papers, :last_synced_at, :datetime
    add_column :projects, :last_synced_at, :datetime
  end
end
