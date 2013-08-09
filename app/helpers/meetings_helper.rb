module MeetingsHelper
  def link_to_previous_period(period, year, month, week, day)
    target_day = 0
    target_week = 0
    case period
    when :month
      dt = Date.civil(year, month, 1) << 1
      target_year = dt.year
      target_month = dt.month

      name = if target_year != year
        "#{month_name(target_month)} #{target_year}"
      else
        "#{month_name(target_month)}"
      end

    when :week
      dt = Date.commercial(year, week, 1) - 7
      target_year = dt.year
      target_month = dt.month
      target_week = dt.cweek

      name = if target_year != year
        "#{target_week}/#{target_year}"
      else
        "#{target_week}"
      end

    when :day
      dt = Date.civil(year, month, day) - 1
      target_year = dt.year
      target_month = dt.month
      target_day = dt.day

      name = if target_month != month
        "#{target_day}/#{target_month}"
      else
        "#{target_day}"
      end
    end

    link_to_period(('&#171; ' + name), target_year, target_month, target_week, target_day)
  end

  def link_to_next_period(period, year, month, week, day)
    target_day = 0
    target_week = 0
    case period
    when :month
      dt = Date.civil(year, month, 1) >> 1
      target_year = dt.year
      target_month = dt.month

      name = if target_year != year
        "#{month_name(target_month)} #{target_year}"
      else
        "#{month_name(target_month)}"
      end

    when :week
      dt = Date.commercial(year, week, 1) + 7
      target_year = dt.year
      target_month = dt.month
      target_week = dt.cweek

      name = if target_year != year
        "#{target_week}/#{target_year}"
      else
        "#{target_week}"
      end

    when :day
      dt = Date.civil(year, month, day) + 1
      target_year = dt.year
      target_month = dt.month
      target_day = dt.day

      name = if target_month != month
        "#{target_day}/#{target_month}"
      else
        "#{target_day}"
      end
    end

    link_to_period((name + ' &#187;'), target_year, target_month, target_week, target_day)
  end

  def link_to_period(link_name, year, month, week=0, day=0)
    link_to(link_name.html_safe, { :project_id => @project, :year => year, :month => month, :week => week, :day => day })
  end

  def render_sidebar_conference
    output = "".html_safe
    begin
      if User.current.allowed_to?(:join_conference, @project) || User.current.allowed_to?(:start_conference, @project)
        url = Setting.plugin_redmine_meetings['bbb_help'].html_safe
        link = url.empty? ? "".html_safe : "&nbsp;&nbsp;<a href='".html_safe + url + "' target='_blank' class='icon icon-help'>&nbsp;</a>".html_safe

        output << "<br/><br/><h3>#{l(:label_conference)}#{link}</h3>".html_safe

        server = Setting.plugin_redmine_meetings['bbb_ip'].empty? ? Setting.plugin_redmine_meetings['bbb_server'] : Setting.plugin_redmine_meetings['bbb_ip']
        meeting_started=false
        #First, test if meeting room already exists
        moderatorPW=Digest::SHA1.hexdigest("root"+@project.identifier)
        data = callApi(server, "getMeetingInfo","meetingID=" + @project.identifier + "&password=" + moderatorPW, true)
        return "" if data.nil?
        doc = REXML::Document.new(data)
        if doc.root.elements['returncode'].text == "FAILED" || doc.root.elements['attendees'].nil? || doc.root.elements['attendees'].size == 0
          output << "#{l(:label_conference_status)}: <b>#{l(:label_conference_status_closed)}</b><br><br>".html_safe
        else
          meeting_started = true
          if Setting.plugin_redmine_meetings['bbb_popup'] != '1'
            output << link_to(l(:label_join_conference), {:controller => 'meetings', :action => 'join_conference', :project_id => @project, :only_path => true})
          else
            output << ("<a href='' onclick='return start_meeting(\"" + url_for(:controller => 'meetings', :action => 'join_conference', :project_id => @project, :only_path => true) + "\");'>#{l(:label_join_conference)}</a>").html_safe
          end
          output << "<br><br>".html_safe
          output << "#{l(:label_conference_status)}: <b>#{l(:label_conference_status_running)}</b>".html_safe
          output << "<br><i>#{l(:label_conference_people)}:</i><br>".html_safe

          doc.root.elements['attendees'].each do |attendee|
            user_id = attendee.elements['userID'].text.to_i
            user = user_id == 0 ? nil : User.find(user_id)
            name = user.nil? ? "&nbsp;&nbsp;- " + attendee.elements['fullName'].text : link_to("- "+ attendee.elements['fullName'].text, :controller => 'users', :action => 'show', :id => user.id)
            output << "#{name}<br>".html_safe
          end
        end

        if !meeting_started
          if User.current.allowed_to?(:start_conference, @project)
            if Setting.plugin_redmine_meetings['bbb_popup'] != '1'
              output << link_to(l(:label_conference_start), {:controller => 'meetings', :action => 'start_conference', :project_id => @project, :only_path => true})
              output << "<br><br>".html_safe
              output << link_to(l(:label_conference_start_with_record), {:controller => 'meetings', :action => 'start_conference', :project_id => @project, :only_path => true, :record => true})
            else
              output << ("<a href='' onclick='return start_meeting(\"" + url_for(:controller => 'meetings', :action => 'start_conference', :project_id => @project, :only_path => true) + "\");'>#{l(:label_conference_start)}</a>").html_safe
            end
            output << "<br><br>".html_safe
          end

        end
        
        #Gravacoes
        output << "<br/><br/><h3>#{l(:label_conference_records)}</h3>".html_safe
        dataRecord = callApi(server, "getRecordings","meetingID=" + @project.identifier, true)
        return "" if dataRecord.nil?
        docRecord = REXML::Document.new(dataRecord)
        if docRecord.root.elements['returncode'].text == "FAILED" || docRecord.root.elements['recordings'].nil? || docRecord.root.elements['recordings'].size == 0
          output << "<b>#{l(:label_conference_records_status)}</b><br><br>".html_safe
        else
          meeting_tz = User.current.time_zone ? User.current.time_zone : ActiveSupport::TimeZone[Setting.plugin_redmine_meetings['meeting_timezone']]
          docRecord.root.elements['recordings'].each do |recording|
            dateRecord = Time.at(recording.elements['startTime'].text.to_i / 1000)
            dataFormated = meeting_tz.local_to_utc(dateRecord).strftime("%F %R") 
            #dataFormated = Time.at(recording.elements['startTime'].text.to_i).strftime("%F %R") 
            output << ("&nbsp;&nbsp;- <a href='#{server}/playback/slides/playback.html?meetingId=" + recording.elements['recordID'].text + "' target='" + (Setting.plugin_redmine_meetings['bbb_popup'] != '1' ? '_self' : '_blank') + "'>"+ format_time(dataFormated) + "</a><br>").html_safe
          end
        end

      end
    rescue => exc
      output = exc
    end
    return output
  end

  def render_sidebar_doodles
    output = "".html_safe
    if User.current.allowed_to?(:view_meeting_doodles, @project, :global => false)
      doodles = MeetingDoodle.find(:all, :conditions => "project_id = #{@project.id}", :order => "created_on DESC")
      doodles.each do |doodle|
        output << "<br/>".html_safe
        output << link_to("-&nbsp;#{h(doodle.title)}".html_safe, {:controller => 'meetings', :action => 'show_doodle', :id => doodle.id, :project_id => @project, :only_path => true})
      end
    end
    return output
  end

  def link_to_meeting(meeting, options={})
    subject = truncate(meeting.subject, :length => 60)
    if options[:truncate]
      subject = truncate(meeting.subject, :length => options[:truncate])
    end
    o = link_to "##{meeting.id}: ", {:controller => "meetings", :action => "show_meeting", :id => meeting},
    :class => meeting.css_classe

    if !options[:no_subject]
      o << h(subject)
    end
    o
  end

  def render_meeting_tooltip(meeting)
    @cached_label_meeting ||= l(:label_title_meeting)
    @cached_label_subject ||= l(:field_subject)
    @cached_label_start_date ||= l(:field_start_date_date)
    @cached_label_end_date ||= l(:field_end_date_date)
    @cached_label_location ||= l(:field_location)
    @cached_label_meeting_web ||= l(:field_meeting_web)

    loc = meeting.web ? l(:field_meeting_web) : h(meeting.location)
    o = link_to "#{@cached_label_meeting} ##{meeting.id}: ", {:controller => "meetings", :action => "show_meeting", :id => meeting},
    :class => meeting.css_classe
    o + "<br />".html_safe +
    "<strong>#{@cached_label_subject}</strong>: #{h(meeting.subject)}<br />".html_safe +
    "<strong>#{@cached_label_start_date}</strong>: #{format_time(meeting.start_date)}<br />".html_safe +
    "<strong>#{@cached_label_end_date}</strong>: #{format_time(meeting.end_date)}<br />".html_safe +
    "<strong>#{@cached_label_location}</strong>: #{loc}".html_safe
  end

  def meeting_style_time (meeting, day, min, max, ind)
    meeting_tz = User.current.time_zone ? User.current.time_zone : ActiveSupport::TimeZone[Setting.plugin_redmine_meetings['meeting_timezone']]
    start_date = meeting_tz.utc_to_local(meeting.start_date.to_time)
    end_date = meeting_tz.utc_to_local(meeting.end_date.to_time)
    if start_date.day < day.day
    top = 0
    else
      h = start_date.hour
      if h < min
      top = (h * 100 / min).to_i
      elsif h > max
      top = ((h - max) * 100 / (24 - max)).to_i
      else
      t = 100
      h = h - min
      t = t + (h * 30) + (start_date.min / 2)
      top = t.to_i
      end
    end

    if end_date.day > day.day
    height = ((max - min) * 30) + 195
    else
      h = end_date.hour
      if h < min
      height = (h * 100 / min).to_i
      elsif h > max
      height = ((h - max) * 100 / (24 - max)).to_i
      else
      t = 100
      h = h - min
      t = t + (h * 30) + (end_date.min / 2)
      height = t.to_i
      end
    end
    height = height - top

    "top: #{top}px; height: #{height}px; z-order: #{top}; position: absolute; left: #{ind * 10}px;"
  end

  private

  def each_xml_element(node, name)
    if node && node[name]
      if node[name].is_a?(Hash)
      yield node[name]
      else
        node[name].each do |element|
          yield element
        end
      end
    end
  end

  def callApi (server, api, param, getcontent)
    salt = Setting.plugin_redmine_meetings['bbb_salt']
    tmp = api + param + salt
    checksum = Digest::SHA1.hexdigest(tmp)
    url = server + "/bigbluebutton/api/" + api + "?" + param + "&checksum=" + checksum

    if getcontent
      begin
        Timeout::timeout(Setting.plugin_redmine_meetings['bbb_timeout'].to_i) do
          connection = open(url)
          connection.read
        end
      rescue Timeout::Error
        return nil
      end
    else
    url
    end

  end

end
