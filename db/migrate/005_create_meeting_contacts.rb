class CreateMeetingContacts < ActiveRecord::Migration
  def change
    create_table :meeting_contacts do |t|
      t.references :meeting
      t.references :easy_contact
    end
    add_index :meeting_contacts, :meeting_id
    add_index :meeting_contacts, :easy_contact_id
  end
end
