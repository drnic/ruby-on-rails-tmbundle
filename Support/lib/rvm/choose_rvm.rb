#!/usr/bin/env ruby

require "rails_bundle_tools"

@rvm_message ||= "To execute this command you need to set the default ruby environment for this project.\n(a project .rvmrc file will be created)\n\nChoose the default environment for this project: "

# assemble a list of all RVM settings available
rubies = `rvm list strings`.split

options = rubies.collect do |ruby|
  gemsets = `rvm #{ruby} gemset list`.split("\n")
  gemsets.shift
  gemsets.delete_if { |vg| vg == '*' }
  
  [ruby, gemsets.map { |g| "#{ruby}@#{g}" }]
end.flatten

# creates the .rvmrc file with the environment configuration chosen.
result = TextMate.standard_choose(@rvm_message, options, :title => "RVM Environment", :button3 => "Set a new gemset...")
case result.first.to_i
when 1
  `(cd #{TextMate.project_directory} ; rvm --create --rvmrc use #{options[result.last.to_i]}) > /dev/null`
when 3
  require File.join(ENV['TM_SUPPORT_PATH'], "lib", "escape")
  require "#{ENV['TM_SUPPORT_PATH']}/lib/osx/plist"
  
  parameters = { 
    "rubies"       => rubies, 
    "selectedRuby" => options[result.last.to_i].split('@').first, 
    'gemset'       => TextMate.project_directory.split('/').last
  }
  command = %Q{#{e_sh ENV['DIALOG']} -cmp #{e_sh parameters.to_plist} #{e_sh("#{ENV['TM_BUNDLE_SUPPORT']}/lib/rvm/nib/SetGemset")}}
  plist = OSX::PropertyList::load(%x{#{command}})
  if plist['result']
    `(cd #{TextMate.project_directory} ; rvm --create --rvmrc use #{plist['selectedRuby']}@#{plist['result']['returnArgument']}  > /dev/null)`
  end
end
