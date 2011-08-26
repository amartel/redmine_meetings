class CreateMeetings < ActiveRecord::Migration
  def self.up
    create_table :meetings do |t|
      t.column :subject, :string
      t.column :location, :string
      t.column :project_id, :integer
      t.column :author_id, :integer
      t.column :description, :text
      t.column :web, :boolean, :default => false, :null => false
      t.column :start_date, :datetime
      t.column :end_date, :datetime
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end
    add_index :meetings, ["project_id"]

    create_table :meeting_settings do |t|
      t.column :project_id, :integer
      t.column :created_at, :timestamp
      t.column :updated_at, :timestamp
      t.column :lock_version, :integer
      t.column :first_hour, :integer
      t.column :last_hour, :integer
    end
  end

  def self.down
    drop_table :meetings
    drop_table :meeting_settings
  end
end
