class CreateDoodles < ActiveRecord::Migration
  def self.up
    create_table :meeting_doodles do |t|
      t.column :title, :string
      t.column :project_id, :integer
      t.column :author_id, :integer
      t.column :description, :text
      t.column :options, :text
      t.column :expiry_date, :datetime
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
      t.column :emails, :text
      t.column :notify_author, :boolean, :default => true, :null => false
    end
    create_table :meeting_doodle_answers do |t|
      t.column :answers, :text
      t.column :meeting_doodle_id, :integer
      t.column :author_id, :integer
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
      t.column :name, :string
    end
    if table_exists?(:doodles)
      #import
      execute <<-SQL
              INSERT INTO meeting_doodles (id, title, project_id, author_id, description, options, expiry_date, created_on, updated_on,emails)
              SELECT id, title, project_id, author_id, description, replace(replace(options,'--- \n',''),'- ',''), expiry_date, created_on, updated_on,''
              FROM doodles
      SQL
      execute <<-SQL
              UPDATE meeting_doodles SET options = left(options, length(options)-1)
      SQL
      execute <<-SQL
              INSERT INTO meeting_doodle_answers (id, answers, meeting_doodle_id, author_id, created_on, updated_on, name)
              SELECT id, answers, doodle_id, author_id, created_on, updated_on, name
              FROM doodle_answers
      SQL
    end
  end

  def self.down
    drop_table :meeting_doodles
    drop_table :meeting_doodle_answers
  end
end
