class AdditionalFields < ActiveRecord::Migration
  def up
    add_column :meetings, :agenda, :text
    add_column :meetings, :highlights, :text
  end

  def down
    remove_column :meetings, :agenda
    remove_column :meetings, :highlights
  end
end
