#map.connect ':controller/:action/:id'
ActionController::Routing::Routes.draw do |map|
  map.connect 'projects/:project_id/meetings/:action', :controller => 'meetings'
  map.connect 'meetings/:action/:id', :controller => 'meetings'
  map.connect 'projects/:id/meetings_settings/:action', :controller => 'meetings_settings'
end
