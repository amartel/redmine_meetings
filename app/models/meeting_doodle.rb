class MeetingDoodle < ActiveRecord::Base

  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  has_many :comments, :as => :commented, :dependent => :delete_all, :order => "created_on"
  has_many :responses, :class_name => 'MeetingDoodleAnswer', :dependent => :destroy, :order => "updated_on", :include => [:author]
  acts_as_watchable

  validates_presence_of :title, :options

  def results
    responses.empty? ? tab_options.fill(0) : responses.map(&:answers).transpose.map { |x| x.select { |v| v }.length }
  end

  def tab_options
    ret = []
    ret = options.split(/\n/) unless options.nil?
  end

  def tab_emails
    ret = []
    ret = ret + emails.gsub(/\n/,',').split(/,/,-1) unless emails.nil?
    ret
  end

  def deliver(to_all)
    recipients = { author.language => [ author.mail ] }
    if to_all
      watcher_users.each do |w|
        recipients[w.language] = update_recipients(recipients, w.language, w.mail)
      end
    if !tab_emails.nil? && !tab_emails.empty?
        tab_emails.each do |e|
          recipients[author.language] = update_recipients(recipients, author.language, e)
        end
      end
    end
    recipients.each do |language,rec|
      MeetingMailer.send_doodle(self, rec, language).deliver
    end
    return true
  end

  def deliver_update(to_all)
    recipients = { author.language => [ author.mail ] }
    if to_all
      watcher_users.each do |w|
        if !responses.find_by_author_id(w.id)
          recipients[w.language] = update_recipients(recipients, w.language, w.mail)
        end
      end
      if !tab_emails.nil? && !tab_emails.empty?
        tab_emails.each do |e|
          if !responses.find_by_name(e.strip)
            recipients[author.language] = update_recipients(recipients, author.language, e.strip)
          end
        end
      end
    end
    recipients.each do |language,rec|
      MeetingMailer.send_doodle(self, rec, language).deliver
    end
    return true
  end
  
  def deliver_invalid_answer(sender_email, user_from)
    MeetingMailer.send_invalid_answer(self, sender_email, user_from.language).deliver
  end
  

  private

  def update_recipients (list, lang, mail)
    mails = list[lang]
    mails ||= []
    mails << mail
  end

end
