class Meeting < ActiveRecord::Base

  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'

  has_many :meeting_contacts, dependent: :destroy
  has_many :easy_contacts, through: :meeting_contacts

  validates_presence_of :start_date, :end_date, :subject
  validates_length_of :subject, :maximum => 255
  validates_length_of :location, :maximum => 255

  acts_as_attachable :delete_permission => :manage_meeting

  acts_as_watchable

  acts_as_searchable :columns => ["#{table_name}.subject", "#{table_name}.description"],
  :include => [:project]

  acts_as_event :title => Proc.new {|o| "#{l(:label_title_meeting)} ##{o.id}: #{format_time(o.start_date)} - #{o.subject}" },
  :description => Proc.new {|o| "#{o.description}"},
  :datetime => :updated_on,
  :type => 'meetings',
  :url => Proc.new {|o| {:controller => 'meetings', :action => 'show_meeting', :id => o.id} }

  acts_as_activity_provider :type => 'meetings',
  :timestamp => "#{table_name}.updated_on",
  :author_key => "#{table_name}.author_id",
  :permission => :view_meetings,
  :find_options => {:joins => "LEFT JOIN #{Project.table_name} ON #{Project.table_name}.id = #{table_name}.project_id"}

  scope :visible, lambda {|*args| { :include => :project,
                                          :conditions => Project.allowed_to_condition(args.shift || User.current, :view_meetings, *args) } }

  def visible?(user=User.current)
    !user.nil? && user.allowed_to?(:view_meetings, project)
  end

  def author
    author_id ? User.find(:first, :conditions => "users.id = #{author_id}") : nil
  end

  def project
    Project.find(:first, :conditions => "projects.id = #{project_id}")
  end

  def start_date_date
    start_date.to_date()
  end

  def start_date_time
    start_date.to_time()
  end

  def end_date_date
    end_date.to_date()
  end

  def end_date_time
    end_date.to_time()
  end

  def <=>(meeting)
    start_date <=> meeting.start_date
  end

  def to_s
    "##{id}: #{start_date} - #{subject}"
  end

  def css_classe
    if web
      "webmeeting"
    else
      "meeting"
    end
  end

  def deliver()
    recipients = { author.language => [ author.mail ] }
    if notify_participants
      watcher_users.each do |w|
        recipients[w.language] = update_recipients(recipients, w.language, w.mail)
      end

      easy_contacts.each do |c|
        contact = get_contact_email_and_language(c)

        recipients[contact[:language]] = update_recipients(recipients, contact[:language], contact[:email])
      end
    end

    recipients.each do |language,rec|
      MeetingMailer.send_meeting(self, rec, language).deliver
    end
    return true
  end

  def deliver_cancel()
    recipients = { author.language => [ author.mail ] }
    if notify_participants
      watcher_users.each do |w|
        recipients[w.language] = update_recipients(recipients, w.language, w.mail)
      end

      easy_contacts.each do |c|
        contact = get_contact_email_and_language(c)

        recipients[contact[:language]] = update_recipients(recipients, contact[:language], contact[:email])
      end
    end
    recipients.each do |language,rec|
      MeetingMailer.cancel_meeting(self, rec, language).deliver
    end
    return true
  end

  def validate
    valide = true
    if !start_date.is_a?(DateTime)
      valide = false
    end
    if !end_date.is_a?(DateTime)
      valide = false
    end
    if start_date > end_date
      valide = false
    end

    if !valide
    errors.add(:end_date_date, :greater_than_start_date)
    end
  end

  def watched_by?(object)
    if object.is_a?(EasyContact)
      easy_contact_ids.include?(object.id)
    else
      super
    end
  end

  private

  def update_recipients (list, lang, mail)
    mails = list[lang]
    mails ||= []
    mails << mail
  end

  def get_contact_email_and_language(object)
    contact = {}
    custom_fields = object.custom_field_values

    email_custom_field = custom_fields.find{ |cfv| cfv.custom_field.field_format == 'email' }
    contact[:email] = email_custom_field.custom_field.custom_values.first.value

    language_custom_field = custom_fields.find{ |cfv| cfv.custom_field.name == 'Language' }
    contact[:language] = language_custom_field.nil? ? 'en' : language_custom_field.custom_field.custom_values.first.value

    contact
  end
end
