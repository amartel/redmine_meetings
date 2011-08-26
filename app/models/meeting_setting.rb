class MeetingSetting < ActiveRecord::Base
  belongs_to :project

  def self.find_or_create(pj_id)
    setting = MeetingSetting.find(:first, :conditions => ['project_id = ?', pj_id])
    unless setting
      setting = MeetingSetting.new
      setting.project_id = pj_id
      setting.first_hour = 6
      setting.last_hour = 22
      setting.save!      
    end
    return setting
  end
end
