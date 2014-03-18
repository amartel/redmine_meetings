class MeetingContact < ActiveRecord::Base
  unloadable

  belongs_to :meeting
  belongs_to :easy_contact
end
