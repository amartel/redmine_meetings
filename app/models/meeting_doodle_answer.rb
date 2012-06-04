class MeetingDoodleAnswer < ActiveRecord::Base
  serialize :answers, Array

  belongs_to :meeting_doodle
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'

  validates_presence_of :answers
  after_save :notify_author
  def answers_with_css_classes
    [self.answers, self.css_classes].transpose
  end

  def css_classes
    return @css_classes unless @css_classes.nil?
    @css_classes = []
    self.answers.each do |answer|
      css = "answer"
      css << " yes" if answer
      css << " no" unless answer
      @css_classes << css
    end
    @css_classes
  end

  def deliver_ak_answer(sender_email, from_user)
    MeetingMailer.send_ak_answer(self, sender_email, from_user.language).deliver
  end

  def notify_author
    if self.meeting_doodle.notify_author
      MeetingMailer.receive_answer(self).deliver
    end
  end
end
