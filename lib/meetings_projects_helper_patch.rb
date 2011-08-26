require_dependency 'projects_helper'

module MeetingsProjectsHelperPatch
  def self.included(base) # :nodoc:
    base.send(:include, ProjectsHelperMethodsMeetings)

    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development

      alias_method_chain :project_settings_tabs, :meetings
    end

  end
end

module ProjectsHelperMethodsMeetings
  def project_settings_tabs_with_meetings
    tabs = project_settings_tabs_without_meetings
    action = {:name => 'meetings', :controller => 'meetings_settings', :action => :show, :partial => 'meetings_settings/show', :label => :meetings}

    tabs << action if User.current.allowed_to?(action, @project)

    tabs
  end
end

ProjectsHelper.send(:include, MeetingsProjectsHelperPatch)
