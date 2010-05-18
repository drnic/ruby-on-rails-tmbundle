#!/usr/bin/env ruby

require "rails_bundle_tools"

@rvm_version = File.open("#{TextMate.project_directory}/.rvmrc").read if File.exists?("#{TextMate.project_directory}/.rvmrc")

if @rvm_version
  @rvm_message = "This project is already configured to use #{@rvm_version}\n\nChange the default environment for this project: "
else
  @rvm_message = "Choose the default environment for this project: "
end

load "#{TextMate.bundle_support}/lib/rvm/choose_rvm.rb"
