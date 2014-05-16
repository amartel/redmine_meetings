class AddActionField < ActiveRecord::Migration
  def up
    add_column :meetings, :action, :text
  end

  def down
    remove_column :meetings, :action
  end
end
