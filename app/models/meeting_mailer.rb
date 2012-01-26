require "tzinfo"
require 'ri_cal'

class MeetingMailer < Mailer
  def send_doodle(doodle, rec, language)
    set_language_if_valid language
    sub = "[#{doodle.project.name} - doodle #{doodle.id}]#{doodle.title}"
    recipients rec
    subject sub
    body :doodle => doodle,
    :doodle_url => url_for(:controller => 'meetings', :action => 'show_doodle', :id => doodle)
    render_multipart("meeting_doodle", body)
  end

  def send_invalid_answer(doodle, rec, language)
    set_language_if_valid language
    sub = "FAILED:[#{doodle.project.name} - doodle #{doodle.id}]#{doodle.title}"
    recipients rec
    subject sub
    body :doodle => doodle
    render_multipart("meeting_doodle_invalid_answer", body)
  end

  def send_ak_answer(response, rec, language)
    set_language_if_valid language
    doodle = response.meeting_doodle
    accepted = []
    doodle.tab_options.zip(response.answers).each do |choice, selected|
      accepted << "[#{choice.strip}]" if selected
    end
    sub = "SUCCESS:[#{doodle.project.name} - doodle #{doodle.id}]#{doodle.title}"
    recipients rec
    subject sub
    body :doodle => doodle, :response => response, :accepted => accepted.join(', '),
    :doodle_url => url_for(:controller => 'meetings', :action => 'show_doodle', :id => doodle)
    render_multipart("meeting_doodle_ak_answer", body)
  end
  
  def receive_answer(answer)
    doodle = answer.meeting_doodle
    name = answer.author.mail ? answer.author.name : answer.name
    set_language_if_valid doodle.author.language
    sub = "ANSWER:[#{doodle.project.name} - doodle #{doodle.id}]#{doodle.title}"
    recipients doodle.author.mail
    subject sub
    body :doodle => doodle, :name => name,
    :doodle_url => url_for(:controller => 'meetings', :action => 'show_doodle', :id => doodle)
    #from User.current.mail
    render_multipart("meeting_doodle_answer", body)
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
        event.dtstart     = tzid.local_to_utc(meeting.start_date)
        event.dtend       = tzid.local_to_utc(meeting.end_date)
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

    sub = "[#{meeting.project.name} - meeting #{meeting.start_date.utc.strftime('%F')}]#{meeting.subject}"
    recipients rec
    subject sub
    reply_to meeting.author.mail
    body :meeting => meeting,
    :conf_url => url_for(:controller => 'meetings', :action => 'join_conference', :project_id => meeting.project),
    :meeting_url => url_for(:controller => 'meetings', :action => 'show_meeting', :id => meeting)
    content_type "multipart/alternative"
    
    part "text/plain" do |p| 
      p.body = render(:file => "meeting.text.erb", :body => body, :layout => 'mailer.text.erb')
    end 

    part "text/html" do |p| 
      p.body = render_message("meeting.html.erb", body) 
    end 
    
    part 'text/calendar; ; charset="utf-8"; method=REQUEST' do |p|
      p.transfer_encoding = "base64"
      cal.instance_variable_set(:@tz_source, nil)
      p.body = cal.to_s
      p.content_disposition = ''
    end

    attachment :content_type => "text/calendar", :filename => "meeting.ics", :body => cal.to_s
     
  end
end
