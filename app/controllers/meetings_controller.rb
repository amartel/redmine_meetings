require 'digest/sha1'

#require 'net/http'
require 'open-uri'
require 'openssl'
require 'base64'
require 'rexml/document'
require "tzinfo"
require 'ri_cal'

class MeetingsController < ApplicationController

  menu_item :meetings
  before_filter :find_project, :find_user
  before_filter :find_doodle, :only => [:show_doodle, :delete_doodle, :edit_doodle, :update_doodle, :answer_doodle]
  before_filter :find_meeting, :only => [:show_meeting, :delete_meeting, :edit_meeting, :update_meeting, :export_meeting]
  before_filter :authorize

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :issues
  helper :projects
  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  helper :attachments
  include AttachmentsHelper

  def index
    @meeting_setting = MeetingSetting.find_or_create @project.id
    @period = :month
    if params[:year] and params[:year].to_i > 1900
      @year = params[:year].to_i
      if params[:month] and params[:month].to_i > 0 and params[:month].to_i < 13
        @month = params[:month].to_i
      end
      if params[:week] and params[:week].to_i > 0 and params[:week].to_i < 53
        @week = params[:week].to_i
        @period = :week
      end
      if params[:day] and params[:day].to_i > 0 and params[:day].to_i < 32
        @day = params[:day].to_i
        @period = :day
      end
    end
    @year ||= Date.today.year
    @month ||= Date.today.month
    @week ||= 0
    @day ||= 0
    if @week != 0
      @month = DateTime.commercial(@year, @week, 1).month
    end
    if @day != 0
      @week = DateTime.civil(@year, @month, @day).cweek
    end

    case @period
    when :month
      @calendar = Meetings::Helpers::Calendar.new(DateTime.civil(@year, @month, 1), current_language, :month)
      @calview = "meetings/month"
    when :week
      @calendar = Meetings::Helpers::Calendar.new(DateTime.commercial(@year, @week, 1), current_language, :week)
      @calview = "meetings/week"
    when :day
      @calendar = Meetings::Helpers::Calendar.new(DateTime.civil(@year, @month, @day), current_language, :day)
      @calview = "meetings/day"
    end

    meetings = []
    meetings += Meeting.find(:all,:include => [ :author ], :conditions => ["(#{Meeting.table_name}.project_id = ?) AND ((start_date BETWEEN ? AND ?) OR (end_date BETWEEN ? AND ?))", @project.id, @calendar.startdt, @calendar.enddt, @calendar.startdt, @calendar.enddt])
    @calendar.meetings = meetings

    render :action => 'index', :layout => false if request.xhr?
  end

  def show_meeting
  end

  def preview_meeting
    @text = params[:meeting][:description]
    render :partial => 'common/preview'
  end

  def new_meeting
    dday = Time.now
    if params[:start]
      dday = Date.parse(params[:start])
    end
    dstart = @meeting_tz.local_to_utc(DateTime.civil(dday.year, dday.month, dday.day, Time.now.hour, Time.now.min)).to_time
    @meeting = Meeting.new(:project => @project, :start_date => dstart, :end_date => (dstart + 3600))
  end

  def create_meeting
    @meeting = Meeting.new(:project => @project, :start_date => DateTime.now, :end_date => DateTime.now + 3600, :author => User.current, :web => false)
    @meeting.subject = params[:meeting][:subject]
    @meeting.description = params[:meeting][:description]
    @meeting.location = params[:meeting][:location]
    @meeting.web = (params[:meeting][:web] == 'on')
    tdate = Date.parse(params[:meeting][:start_date_date])
    @meeting.start_date = @meeting_tz.local_to_utc(DateTime.civil(tdate.year, tdate.month, tdate.day, params[:start_time][:hour].to_i, params[:start_time][:minute].to_i))
    tdate = Date.parse(params[:meeting][:end_date_date])
    @meeting.end_date = @meeting_tz.local_to_utc(DateTime.civil(tdate.year, tdate.month, tdate.day, params[:end_time][:hour].to_i, params[:end_time][:minute].to_i))
    @meeting.watcher_user_ids = params[:watchers]
    @meeting.notify_participants = (params[:meeting][:notify_participants] == 'on')
    if @meeting.save
      attachments = Attachment.attach_files(@meeting, params[:attachments])
      render_attachment_warning_if_needed(@meeting)
      @meeting.deliver()
      flash[:notice] = l(:notice_successful_create)
      redirect_to :action => 'index', :project_id => @project, :year => @meeting.start_date.year, :week => @meeting.start_date.to_date.cweek
    else
      render :action => 'new_meeting', :project_id => @project
    end
  end

  def edit_meeting
  end

  def update_meeting
    @meeting.subject = params[:meeting][:subject]
    @meeting.description = params[:meeting][:description]
    @meeting.location = params[:meeting][:location]
    @meeting.web = (params[:meeting][:web] == 'on')
    tdate = Date.parse(params[:meeting][:start_date_date])
    @meeting.start_date = @meeting_tz.local_to_utc(DateTime.civil(tdate.year, tdate.month, tdate.day, params[:start_time][:hour].to_i, params[:start_time][:minute].to_i))
    tdate = Date.parse(params[:meeting][:end_date_date])
    @meeting.end_date = @meeting_tz.local_to_utc(DateTime.civil(tdate.year, tdate.month, tdate.day, params[:end_time][:hour].to_i, params[:end_time][:minute].to_i))
    @meeting.watcher_user_ids = params[:watchers]
    @meeting.notify_participants = (params[:meeting][:notify_participants] == 'on')
    if @meeting.save
      attachments = Attachment.attach_files(@meeting, params[:attachments])
      render_attachment_warning_if_needed(@meeting)
      @meeting.deliver()
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => 'index', :project_id => @project, :year => @meeting.start_date.year, :week => @meeting.start_date.to_date.cweek
    else
      render :action => 'edit_meeting', :project_id => @project
    end
  end

  def delete_meeting
    if @meeting.start_date > DateTime.now
      @meeting.deliver_cancel()
    end
    @meeting.destroy
    redirect_to :action => 'index', :project_id => @project
  end

  def export_meeting
    meetings = [ @meeting ]
    download_ics_for(meetings)
  end

  def export_meetings
    meetings = []
    meetings += Meeting.find(:all,:include => [ :author ], :conditions => ["((start_date > ?) OR (end_date > ?))", DateTime.now, DateTime.now])
    download_ics_for(meetings)
  end

  def show_doodle
    @author = @doodle.author
    @responses = @doodle.responses
    @responses ||= []
    if User.current.allowed_to?(:answer_doodle, @project)
      # Give the current user an empty answer if she hasn't answered yet and the doodle is active
      @response = @responses.find_by_author_id(User.current.id) unless !User.current.mail
      @response ||= MeetingDoodleAnswer.new :author => nil, :answers => Array.new(@doodle.tab_options.size, false)
      #@response.answers ||= Array.new(@doodle.tab_options.size, false)
      @responses = @responses | [ @response ]
    end
  end

  def new_doodle
    @doodle = MeetingDoodle.new(:project => @project)
  end

  def preview_doodle
    options = params[:meeting_doodle][:options].gsub(/\r/,'').split(/\n/)
    tab = "\n\n"
    if !options.empty?
      tab << "||"
      options.each do |opt|
        tab << "_.#{opt}|"
      end
      tab << "\n|#{User.current}|"
      options.each do |opt|
        tab << "=. <input type='checkbox'>|"
      end
      tab << "\n"
    end
    @text = params[:meeting_doodle][:description]
    @text ||= ""
    @text << tab
    render :partial => 'common/preview'
  end

  def create_doodle
    @doodle = MeetingDoodle.new(:project => @project, :author => User.current)
    @doodle.attributes = params[:meeting_doodle]
    @doodle.notify_author = (params[:meeting_doodle][:notify_author] == 'on')
    @doodle.watcher_user_ids = params[:watchers]
    if @doodle.save
      @doodle.deliver((params[:notify_participants] == 'on'))
      flash[:notice] = l(:notice_successful_create)
      redirect_to :action => 'show_doodle', :id => @doodle
    else
      render :action => 'new_doodle', :project_id => @project
    end
  end

  def edit_doodle
  end

  def update_doodle
    if params[:delete_answers] == 'on'
      @doodle.responses.each do |r|
        r.destroy
      end
    else
      if (@doodle.options != params[:meeting_doodle][:options] && !@doodle.responses.empty?)
        #options changed and there are responses!!!
        nl = params[:meeting_doodle][:options].split(/\n/).length
        delta = nl - @doodle.tab_options.length
        if delta != 0
          @doodle.responses.each do |r|
            if delta > 0
              for i in 1..delta
                r.answers << false
              end
            else
              r.answers = r.answers[0,nl]
            end
            r.save
          end
        end
      end
    end
    @doodle.attributes = params[:meeting_doodle]
    @doodle.author = User.current
    @doodle.notify_author = (params[:meeting_doodle][:notify_author] == 'on')
    @doodle.watcher_user_ids = params[:watchers]
    if @doodle.save
      @doodle.deliver_update((params[:notify_participants] == 'on'))
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => 'show_doodle', :id => @doodle
    else
      render :action => 'new_doodle', :project_id => @project
    end
  end

  def delete_doodle
    @doodle.destroy
    redirect_to :action => 'index', :project_id => @project
  end

  def answer_doodle
    @user = User.current
    params[:answers] ||= []
    @answers = Array.new(@doodle.tab_options.size) { |index| params[:answers].include?(index.to_s) }
    if @user.mail
      @response = @doodle.responses.find_or_initialize_by_author_id(@user.id)
    elsif !params[:name].to_s.empty?
      @response = MeetingDoodleAnswer.new(:meeting_doodle => @doodle, :author => @user)
    else
      redirect_to :action => 'show_doodle', :id => @doodle
    end
    @response.answers = @answers
    @response.name = params[:name]
    if @response.save
      flash[:notice] = l(:doodle_update_successfull)
    else
      flash[:warning] = l(:doodle_update_unseccessfull)
    end
    redirect_to :action => 'show_doodle', :id => @doodle
  end

  def join_conference
    back_url = Setting.plugin_redmine_meetings['bbb_url'].empty? ? request.referer.to_s : Setting.plugin_redmine_meetings['bbb_url']
    if params[:from_mail]
      back_url = url_for(:controller => 'meetings', :action => 'index', :project_id => @project)
    end
    ok_to_join = false
    #First, test if meeting room already exists
    server = Setting.plugin_redmine_meetings['bbb_ip'].empty? ? Setting.plugin_redmine_meetings['bbb_server'] : Setting.plugin_redmine_meetings['bbb_ip']
    moderatorPW=Digest::SHA1.hexdigest("root"+@project.identifier)
    attendeePW=Digest::SHA1.hexdigest("guest"+@project.identifier)

    data = callApi(server, "getMeetingInfo","meetingID=" + @project.identifier + "&password=" + moderatorPW, true)
    redirect_to back_url if data.nil?
    doc = REXML::Document.new(data)
    if doc.root.elements['returncode'].text != "FAILED"
      moderatorPW = doc.root.elements['moderatorPW'].text
      server = Setting.plugin_redmine_meetings['bbb_server']
      url = callApi(server, "join", "meetingID=" + @project.identifier + "&password="+ (@user.allowed_to?(:conference_moderator, @project) ? moderatorPW : attendeePW) + "&fullName=" + CGI.escape(User.current.name) + "&userID=" + @user.id.to_s, false)
      redirect_to url
    else
      #Meeting room doesn't exist
      start_conference
      #redirect_to back_url
    end
  end

  def start_conference
    back_url = Setting.plugin_redmine_meetings['bbb_url'].empty? ? request.referer.to_s : Setting.plugin_redmine_meetings['bbb_url']
    if params[:from_mail]
      back_url = url_for(:controller => 'meetings', :action => 'index', :project_id => @project)
    end
    ok_to_join = false
    #First, test if meeting room already exists
    server = Setting.plugin_redmine_meetings['bbb_ip'].empty? ? Setting.plugin_redmine_meetings['bbb_server'] : Setting.plugin_redmine_meetings['bbb_ip']
    moderatorPW=Digest::SHA1.hexdigest("root"+@project.identifier)
    attendeePW=Digest::SHA1.hexdigest("guest"+@project.identifier)

    data = callApi(server, "getMeetingInfo","meetingID=" + @project.identifier + "&password=" + moderatorPW, true)
    redirect_to back_url if data.nil?
    doc = REXML::Document.new(data)
    if doc.root.elements['returncode'].text == "FAILED"
      #If not, we created it...
      if @user.allowed_to?(:start_conference, @project)
        bridge = "77777" + @project.id.to_s
        bridge = bridge[-5,5]
        s = Setting.plugin_redmine_meetings['bbb_initpres']
        loadPres = ""
        if !s.nil? && !s.empty?
          loadPres = "<?xml version='1.0' encoding='UTF-8'?><modules><module name='presentation'><document url='#{s}'/></module></modules>"
        end
        record = "false"
        if params[:record]
          record = "true"
        end
        data = callApi(server, "create","name=" + CGI.escape(@project.name) + "&meetingID=" + @project.identifier + "&attendeePW=" + attendeePW + "&moderatorPW=" + moderatorPW + "&logoutURL=" + back_url + "&voiceBridge=" + bridge + "&record=" + record, true, loadPres)
        ok_to_join = true
      end
    else
      ok_to_join = true if @user.allowed_to?(:join_conference, @project)
    end
    #Now, join meeting...
    if ok_to_join
      join_conference
    else
      redirect_to back_url
    end
  end

  def delete_conference
    server = Setting.plugin_redmine_meetings['bbb_ip'].empty? ? Setting.plugin_redmine_meetings['bbb_server'] : Setting.plugin_redmine_meetings['bbb_ip']
    if params[:record_id]
      data = callApi(server, "getRecordings","meetingID=" + @project.identifier, true)
      if !data.nil?
        docRecord = REXML::Document.new(data)
        docRecord.root.elements['recordings'].each do |recording|
          if recording.elements['recordID'].text == params[:record_id]
            data = callApi(server, "deleteRecordings","recordID=" + params[:record_id], true)
            break
          end
        end
      end
    end
    redirect_to :action => 'index', :project_id => @project
  end

  private

  def download_ics_for(meetings)
    cal = RiCal.Calendar do |cal|
      cal.prodid           = "BIOPROJ"
      cal.method_property  = ":REQUEST"
      meetings.each do |meeting|
        desc = ''
        desc << meeting.description
        if meeting.web
          desc << "\n"
          desc << l(:content_meeting_email3, url_for(:controller => 'meetings', :action => 'join_conference', :project_id => meeting.project))
        end
        tzid = User.current.time_zone ? User.current.time_zone : ActiveSupport::TimeZone[Setting.plugin_redmine_meetings['meeting_timezone']]
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
    end
    send_data cal.to_s, :filename => "export.ics",
                                 :type => 'text/calendar',
                                 :disposition => 'inline'
  end

  def callApi (server, api, param, getcontent, data="")
    salt = Setting.plugin_redmine_meetings['bbb_salt']
    tmp = api + param + salt
    checksum = Digest::SHA1.hexdigest(tmp)
    url = server + "/bigbluebutton/api/" + api + "?" + param + "&checksum=" + checksum

    if getcontent
      begin
        Timeout::timeout(Setting.plugin_redmine_meetings['bbb_timeout'].to_i) do
          if data.empty?
            connection = open(url)
            connection.read
          else
            uri = URI.parse(url)
            res = Net::HTTP.start(uri.host, uri.port) {|http|
              response, body = http.post(uri.path+"?" + uri.query, data, {'Content-type'=>'text/xml; charset=utf-8'})
              body
            }
          end
        end
      rescue Timeout::Error
        return nil
      end
    else
      url
    end
  end

  def find_project
    # @project variable must be set before calling the authorize filter
    if params[:project_id]
      @project = Project.find(params[:project_id])
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_user
    User.current = find_current_user
    @user = User.current
    @meeting_tz = User.current.time_zone ? User.current.time_zone : ActiveSupport::TimeZone[Setting.plugin_redmine_meetings['meeting_timezone']]
  end

  def find_doodle
    @doodle = MeetingDoodle.find(params[:id], :include => [:project, :author, :responses])
    @project = @doodle.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_meeting
    @meeting = Meeting.find(params[:id], :include => [:project, :author])
    @project = @meeting.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Authorize the user for the requested action
  def authorize(ctrl = params[:controller], action = params[:action], global = false)
    allowed = User.current.allowed_to?({:controller => ctrl, :action => action}, @project, :global => global)
    allowed ? true : deny_access
  end

end
