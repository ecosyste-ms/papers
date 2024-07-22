class AddUrlsToPapers < ActiveRecord::Migration[7.1]
  def change
    add_column :papers, :urls, :text, array: true, default: []
  end
end
