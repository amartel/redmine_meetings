#Patches
require 'redmine_meetings/patches/mail_handler_patch'
require 'redmine_meetings/patches/projects_helper_patch'

#Extend the ActionMailer to include plugin in its paths
ActionMailer::Base.append_view_path(File.expand_path(File.dirname(__FILE__) + '/../app/views'))
