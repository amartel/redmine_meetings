class MeetingsNotification < ActiveRecord::Migration
  def up
    add_column :meetings, :notify_participants, :boolean, :default => false, :null => false
  end

  def down
    remove_column :meetings, :notify_participants
  end
end
