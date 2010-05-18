#!/usr/bin/env ruby

require "rails_bundle_tools"
require "#{ENV['TM_SUPPORT_PATH']}/lib/escape"
require "#{ENV['TM_SUPPORT_PATH']}/lib/osx/plist"

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
# if selected = TextMate.choose(@rvm_message, options, :title => "RVM Environment")
#   File.open("#{TextMate.project_directory}/.rvmrc", 'w') {|f| f.write("rvm #{options[selected]}") }
# end

result = TextMate.standard_choose(@rvm_message, options, :title => "RVM Environment", :button3 => "Set new gemset...")
case result.first
when '1'
  File.open("#{TextMate.project_directory}/.rvmrc", 'w') {|f| f.write("rvm #{options[selected]}") }
when '3'
  parameters = { "interpreters" => ruby_versions }
  
  command = %Q{#{e_sh ENV['DIALOG']} -cmp #{e_sh parameters.to_plist} #{e_sh("/Users/carlosbrando/Desktop/Test.nib")}}
  plist = OSX::PropertyList::load(%x{#{command}})
  if plist['result']
    block.call(plist)
  end
  
  interpreter = plist['selectedInterpreter']
  gemset      = plist['gemset']
  
  # ENV['TESTE'] = "true"
  
  # puts `#{ENV['TM_BUNDLE_SUPPORT']}/lib/rvm/create_gemset.sh`
  # puts `echo $(rvm #{interpreter} ; rvm gemset create '#{gemset}')`
  # puts interpreter
  # puts system("rvm #{interpreter} | ruby -v")
  #   exit
  File.open("#{TextMate.project_directory}/.rvmrc", 'w') {|f| f.write("rvm #{interpreter}@#{gemset}") }
end