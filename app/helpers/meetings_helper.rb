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
    link_to(link_name, { :project_id => @project, :year => year, :month => month, :week => week, :day => day })
  end

  def render_sidebar_conference
    output = ""
    begin
      if User.current.allowed_to?(:join_conference, @project) || User.current.allowed_to?(:start_conference, @project)
        url = Setting.plugin_redmine_meetings['bbb_help']
        link = url.empty? ? "" : "&nbsp;&nbsp;<a href='" + url + "' target='_blank' class='icon icon-help'>&nbsp;</a>"

        output << "<h3>#{l(:label_conference)}#{link}</h3>"

        server = Setting.plugin_redmine_meetings['bbb_ip'].empty? ? Setting.plugin_redmine_meetings['bbb_server'] : Setting.plugin_redmine_meetings['bbb_ip']
        meeting_started=false
        #First, test if meeting room already exists
        moderatorPW=Digest::SHA1.hexdigest("root"+@project.identifier)
        data = callApi(server, "getMeetingInfo","meetingID=" + @project.identifier + "&password=" + moderatorPW, true)
        return "" if data.nil?
        doc = REXML::Document.new(data)
        if doc.root.elements['returncode'].text == "FAILED"
          output << "#{l(:label_conference_status)}: <b>#{l(:label_conference_status_closed)}</b><br><br>"
        else
          meeting_started = true
          if Setting.plugin_redmine_meetings['bbb_popup'] != '1'
            output << link_to(l(:label_join_conference), {:controller => 'meetings', :action => 'join_conference', :project_id => @project, :only_path => true})
          else
            output << "<a href='' onclick='javascript:var wihe = \"width=\"+screen.availWidth+\",height=\"+screen.availHeight; open(\"" + url_for(:controller => 'meetings', :action => 'join_conference', :project_id => @project, :only_path => true) + "\",\"Meeting\",\"directories=no,location=no,resizable=yes,scrollbars=yes,status=no,toolbar=no,\" + wihe);return false;'>#{l(:label_join_conference)}</a>"
          end
          output << "<br><br>"
          output << "#{l(:label_conference_status)}: <b>#{l(:label_conference_status_running)}</b>"
          output << "<br><i>#{l(:label_conference_people)}:</i><br>"

          doc.root.elements['attendees'].each do |attendee|
            name=attendee.elements['fullName'].text
            output << "&nbsp;&nbsp;- #{name}<br>"
          end
        end

        if !meeting_started
          if User.current.allowed_to?(:start_conference, @project)
            if Setting.plugin_redmine_meetings['bbb_popup'] != '1'
              output << link_to(l(:label_conference_start), {:controller => 'meetings', :action => 'start_conference', :project_id => @project, :only_path => true})
            else
              output << "<a href='' onclick='javascript:var wihe = \"width=\"+screen.availWidth+\",height=\"+screen.availHeight; open(\"" + url_for(:controller => 'meetings', :action => 'start_conference', :project_id => @project, :only_path => true) + "\",\"Meeting\",\"directories=no,location=no,resizable=yes,scrollbars=yes,status=no,toolbar=no,\" + wihe);return false;'>#{l(:label_conference_start)}</a>"
            end
            output << "<br><br>"
          end

        end

      end
    rescue
      logger.error("erreur....")
      output = ""
    end
    return output
  end

  def render_sidebar_doodles
    output = ""
    if User.current.allowed_to?(:view_meeting_doodles, @project, :global => false)
      doodles = MeetingDoodle.find(:all, :conditions => "project_id = #{@project.id}", :order => "created_on DESC")
      doodles.each do |doodle|
        output << "<br/>"
        output << link_to("-&nbsp;#{h(doodle.title)}", {:controller => 'meetings', :action => 'show_doodle', :id => doodle.id, :project_id => @project, :only_path => true}) + " <span style='font-size: smaller;'>(#{format_date(doodle.created_on)})</span>"
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
    o + "<br />" +
    "<strong>#{@cached_label_subject}</strong>: #{h(meeting.subject)}<br />" +
    "<strong>#{@cached_label_start_date}</strong>: #{format_time(meeting.start_date)}<br />" +
    "<strong>#{@cached_label_end_date}</strong>: #{format_time(meeting.end_date)}<br />" +
    "<strong>#{@cached_label_location}</strong>: #{loc}"
  end

  def meeting_style_time (meeting, day, min, max, ind)
    if meeting.start_date.day < day.day
      top = 0
    else
      h = meeting.start_date.hour
      if h < min
        top = (h * 100 / min).to_i
      elsif h > max
        top = ((h - max) * 100 / (24 - max)).to_i
      else
        t = 100
        h = h - min
        t = t + (h * 30) + (meeting.start_date.min / 2)
        top = t.to_i
      end
    end

    if meeting.end_date.day > day.day
      height = ((max - min) * 30) + 195
    else
      h = meeting.end_date.hour
      if h < min
        height = (h * 100 / min).to_i
      elsif h > max
        height = ((h - max) * 100 / (24 - max)).to_i
      else
        t = 100
        h = h - min
        t = t + (h * 30) + (meeting.end_date.min / 2)
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
