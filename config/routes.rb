#map.connect ':controller/:action/:id'
ActionController::Routing::Routes.draw do |map|
  map.connect 'projects/:id/meetings/:action', :controller => 'meetings'
  map.connect 'projects/:id/meetings_settings/:action', :controller => 'meetings_settings'
end
