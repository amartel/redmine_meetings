# Meetings plugin for Redmine
# Copyright (C) 2011 Arnaud MARTEL
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
require 'redmine'
Dir::foreach(File.join(File.dirname(__FILE__), 'lib')) do |file|
  next unless /\.rb$/ =~ file
  require file
end

Redmine::Plugin.register :redmine_meetings do
  name 'Meetings plugin'
  author 'Arnaud Martel'
  description 'plugin to manage meetings in REDMINE'
  version '0.1.0'
  requires_redmine :version_or_higher => '1.3.0'
  
  settings :default => {'bbb_server' => '', 'bbb_salt' => '', 'bbb_timeout' => '3', 'meeting_timezone' => 'Paris'}, :partial => 'meetings_settings/settings'

  project_module :meetings do
    permission :meetings_settings, {:meetings_settings => [:show, :update]}
    permission :view_meeting_doodles, {:meetings => [:show_doodle]}
    permission :manage_doodle, {:meetings => [:new_doodle, :create_doodle, :edit_doodle, :update_doodle, :delete_doodle, :preview_doodle]}
    permission :answer_doodle, {:meetings => [:answer_doodle]}
    permission :view_meetings, {:meetings => [:show_meeting, :export_meeting, :export_meetings]}
    permission :manage_meeting, {:meetings => [:new_meeting, :create_meeting, :edit_meeting, :update_meeting, :delete_meeting, :preview_meeting]}
    permission :join_conference, :meetings => :join_conference
    permission :start_conference, :meetings => :start_conference
    permission :meeting, { :meetings => :index}, :public => true
    permission :conference_moderator, {}
      
  end
  
  menu :project_menu, :meetings, { :controller => 'meetings', :action => 'index' }, :param => :project_id, :caption => :label_meeting_plural

  # Meetings are added to the activity view
  activity_provider :meetings, :class_name => 'Meeting', :default => false
  Redmine::Search.available_search_types << 'meetings'

end