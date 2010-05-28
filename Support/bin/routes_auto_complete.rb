#!/usr/bin/env ruby

require File.join(ENV['TM_SUPPORT_PATH'], 'lib', 'ui.rb')
require File.join(ENV['TM_PROJECT_DIRECTORY'], 'config', 'environment')

routes = ActionController::Routing::Routes.named_routes.routes.keys.map do |route|
  %w(_path _url).map { |extension| route.to_s + extension } if route != :rails_info_properties
end

TextMate::UI.complete(routes.flatten.compact.sort, :extra_chars => "_")