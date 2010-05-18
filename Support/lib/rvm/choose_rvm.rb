#!/usr/bin/env ruby

require "rails_bundle_tools"

@rvm_message ||= "To execute this command you need to set the default ruby environment for this project.\n(a project .rvmrc file will be created)\n\nChoose the default environment for this project: "

# assemble a list of all RVM settings available
ruby_versions = `rvm list strings`.split
options = ruby_versions.collect do |ruby|
  gemsets = `rvm #{ruby} gemset list`.split("\n")
  gemsets.shift
  gemsets.delete_if { |vg| vg == '*' }
  
  [ruby, gemsets.map { |g| "#{ruby}@#{g}" }]
end.flatten

# creates the .rvmrc file with the environment configuration chosen.
if selected = TextMate.choose(@rvm_message, options, :title => "RVM Environment")
  File.open("#{TextMate.project_directory}/.rvmrc", 'w') {|f| f.write("rvm #{options[selected]}") }
end
