#map.connect ':controller/:action/:id'
RedmineApp::Application.routes.draw do
# ActionController::Routing::Routes.draw do |map|
#  map.connect 'projects/:project_id/meetings/:action', :controller => 'meetings'
#  map.connect 'meetings/:action/:id', :controller => 'meetings'
#  map.connect 'projects/:id/meetings_settings/:action', :controller => 'meetings_settings'
  match 'projects/:project_id/meetings/:action', :via => [:get], :controller => 'meetings'
  match 'meetings/:action/:id', :via => [:get], :controller => 'meetings'
  match 'projects/:id/meetings_settings/:action', :via => [:get], :controller => 'meetings_settings'

end
