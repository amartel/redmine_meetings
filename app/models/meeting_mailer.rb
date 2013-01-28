require "tzinfo"
require 'ri_cal'

class MeetingMailer < Mailer

  def send_doodle(doodle, rec, language)
    set_language_if_valid language
    sub = "[#{doodle.project.name} - doodle #{doodle.id}]#{doodle.title}"
    @doodle = doodle
    @doodle_url = url_for(:controller => 'meetings', :action => 'show_doodle', :id => doodle)
    mail :to => rec,
      :subject => sub
  end

  def send_invalid_answer(doodle, rec, language)
    set_language_if_valid language
    sub = "FAILED:[#{doodle.project.name} - doodle #{doodle.id}]#{doodle.title}"
    @doodle = doodle
    mail :to => rec,
      :subject => sub
  end

  def send_ak_answer(response, rec, language)
    set_language_if_valid language
    doodle = response.meeting_doodle
    accepted = []
    doodle.tab_options.zip(response.answers).each do |choice, selected|
      accepted << "[#{choice.strip}]" if selected
    end
    sub = "SUCCESS:[#{doodle.project.name} - doodle #{doodle.id}]#{doodle.title}"

    @doodle = doodle
    @response = response
    @accepted = accepted.join(', ')
    @doodle_url = url_for(:controller => 'meetings', :action => 'show_doodle', :id => doodle)

    mail :to => rec,
      :subject => sub
  end

  def receive_answer(answer)
    doodle = answer.meeting_doodle
    name = answer.author.mail ? answer.author.name : answer.name
    set_language_if_valid doodle.author.language
    sub = "ANSWER:[#{doodle.project.name} - doodle #{doodle.id}]#{doodle.title}"
    @doodle = doodle
    @name = name
    @doodle_url = url_for(:controller => 'meetings', :action => 'show_doodle', :id => doodle)

    mail :to => doodle.author.mail,
      :subject => sub
  end

  def send_meeting(meeting, rec, language)
    set_language_if_valid language

    tzid = User.current.time_zone ? User.current.time_zone : ActiveSupport::TimeZone[Setting.plugin_redmine_meetings['meeting_timezone']]
    desc = ''
    desc << meeting.description
    if meeting.web
      desc << "\n"
      desc << l(:content_meeting_email3, url_for(:controller => 'meetings', :action => 'join_conference', :project_id => meeting.project))
    end
    cal = RiCal.Calendar do |cal|
      cal.prodid           = "BIOPROJ"
      cal.method_property  = ":REQUEST"
      cal.event do |event|
        event.dtstamp     = DateTime.now.utc
        event.summary     = meeting.subject
        event.description = desc
        event.dtstart     = meeting.start_date.to_time
        event.dtend       = meeting.end_date.to_time
        event.location    = meeting.web ? l(:field_meeting_web) : meeting.location
        meeting.watcher_users.collect.sort.each do |user|
          event.add_attendee  user.mail
        end
        event.organizer   = meeting.author.mail
        event.uid         = "B10AA0B0-0000-0000-#{"%012d" % meeting.id}"
        event.status      = "CONFIRMED"
        event.class_property = ":PUBLIC"
        event.priority    = 5
        event.transp      = "OPAQUE"
        event.alarm do
          description "REMINDER"
          action "DISPLAY"
          trigger_property ";RELATED=START:-PT5M"
        end
      end
    end


    @author = User.anonymous

    sub = "[#{meeting.project.name} - meeting #{meeting.start_date.strftime('%F')}]#{meeting.subject}"
    @meeting = meeting
    @conf_url = url_for(:controller => 'meetings', :action => 'join_conference', :project_id => meeting.project)
    @meeting_url = url_for(:controller => 'meetings', :action => 'show_meeting', :id => meeting)
    @meeting_tz = User.current.time_zone ? User.current.time_zone : ActiveSupport::TimeZone[Setting.plugin_redmine_meetings['meeting_timezone']]
    #content_type "multipart/alternative"

    attachments['meeting.ics'] = {:mime_type => "text/calendar", :content => cal.to_s}
    mail :to => rec,
      :subject => sub,
      :reply_to => meeting.author.mail
  end

def cancel_meeting(meeting, rec, language)
  set_language_if_valid language

  tzid = User.current.time_zone ? User.current.time_zone : ActiveSupport::TimeZone[Setting.plugin_redmine_meetings['meeting_timezone']]
  desc = ''
  desc << meeting.description
  if meeting.web
    desc << "\n"
    desc << l(:content_meeting_email3, url_for(:controller => 'meetings', :action => 'join_conference', :project_id => meeting.project))
  end
  cal = RiCal.Calendar do |cal|
    cal.prodid           = "BIOPROJ"
    cal.method_property  = ":CANCEL"
    cal.event do |event|
      event.dtstamp     = DateTime.now.utc
      event.summary     = meeting.subject
      event.description = desc
      event.dtstart     = meeting.start_date.to_time
      event.dtend       = meeting.end_date.to_time
      event.location    = meeting.web ? l(:field_meeting_web) : meeting.location
      meeting.watcher_users.collect.sort.each do |user|
        event.add_attendee  user.mail
      end
      event.organizer   = meeting.author.mail
      event.uid         = "B10AA0B0-0000-0000-#{"%012d" % meeting.id}"
      event.status      = "CANCELLED"
      event.class_property = ":PUBLIC"
      event.priority    = 5
      event.transp      = "OPAQUE"
      event.alarm do
        description "REMINDER"
        action "DISPLAY"
        trigger_property ";RELATED=START:-PT5M"
      end
    end
  end


  @author = User.anonymous

  sub = "[#{meeting.project.name} - meeting #{meeting.start_date.strftime('%F')}]#{meeting.subject}"
  @meeting = meeting
  @conf_url = url_for(:controller => 'meetings', :action => 'join_conference', :project_id => meeting.project)
  @meeting_url = url_for(:controller => 'meetings', :action => 'show_meeting', :id => meeting)
  @meeting_tz = User.current.time_zone ? User.current.time_zone : ActiveSupport::TimeZone[Setting.plugin_redmine_meetings['meeting_timezone']]
  #content_type "multipart/alternative"

  attachments['meeting.ics'] = {:mime_type => "text/calendar", :content => cal.to_s}
  mail :to => rec,
    :subject => sub,
    :reply_to => meeting.author.mail
end

end
