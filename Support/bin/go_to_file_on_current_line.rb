#!/usr/bin/env ruby

# Copyright:
#   (c) 2006 syncPEOPLE, LLC.
#   Visit us at http://syncpeople.com/
# Author: Duane Johnson (duane.johnson@gmail.com)
# Description:
#   Makes an intelligent decision on which file to go to based on the current line or current context.

require 'rails_bundle_tools'

def strip_erb(string)
  string.gsub('<%=', '').gsub('<%', '').gsub('%>', '')
end

def remove_quotes_or_colon(string_or_array)
  if string_or_array.is_a? Array
    string_or_array.map { |s| (s.scan(/^['"](.+)['"]$/).flatten.first || s.scan(/^:(.+)$/).flatten.first || s).strip }
  else
    (string_or_array.scan(/^['"](.+)['"]$/).flatten.first ||
     string_or_array.scan(/^:(.+)$/).flatten.first ||
     string_or_array).strip
  end
end

current_file = RailsPath.new

# If the current line contains "render :partial", then open the partial.
case TextMate.current_line

  # Example: render :partial => 'account/login'
  when /render[\s\(].*:partial\s*=>\s*['"](.+?)['"]/
    partial_name = $1
    modules = current_file.modules + [current_file.controller_name]
  
    # Check for absolute path to partial
    if partial_name.include?('/')
      pieces = partial_name.split('/')
      partial_name = pieces.pop
      modules = pieces
    end

    partial = File.join(current_file.rails_root, 'app', 'views', modules, "_#{partial_name}.rhtml")
    TextMate.open(partial)

  # Example: render :action => 'login'
  when /render[\s\(].*:action\s*=>\s*['"](.+?)['"]/
    action = $1
    if current_file.file_type == :controller
      current_file.buffer.line_number = 0
      if search = current_file.buffer.find { /def\s+#{action}\b/ }
        TextMate.open(current_file, search[1])
      end
    else
      puts "Don't know where to go when rendering an action from outside a controller"
      exit
    end

  # Example: redirect_to :action => 'login'
  when /(redirect_to|redirect_back_or_default)[\s\(]/
    controller = action = nil
    controller = $1 if TextMate.current_line =~ /.*:controller\s*=>\s*['"](.+?)['"]/
    action = $1 if TextMate.current_line =~ /.*:action\s*=>\s*['"](.+?)['"]/

    unless current_file.file_type == :controller
      puts "Don't know where to go when redirecting from outside a controller"
      exit
    end
    
    if controller.nil?
      controller_file = current_file
    else
      # Check for modules
      if controller.include?('/')
        pieces = controller.split('/')
        controller = pieces.pop
        modules = pieces
      end
      other_path = File.join(current_file.rails_root, 'app', 'controllers', modules, "#{controller}_controller.rb")
      controller_file = RailsPath.new(other_path)
    end

    if search = controller_file.buffer.find(:direction => :backwards) { /def\s+#{action}\b/ }
      TextMate.open(controller_file, search[1])
    else
      puts "Couldn't find the #{action} action inside '#{controller_file.basename}'"
      exit
    end

  # Example: <script src="/javascripts/controls.js">
  when /\<script.+src=['"](.+\.js)['"]/
    javascript = $1
    if javascript =~ %r{^https?://}
      TextMate.open_url javascript
    else
      full_path = File.join(current_file.rails_root, 'public', javascript)
      TextMate.open full_path
    end

  # Example: <%= javascript_include_tag 'general' %>
  # require_javascript is used by bundled_resource plugin
  when /(require_javascript|javascript_include_tag)\b/
    if match = TextMate.current_line.unstringify_hash_arguments.find_nearest_string_or_symbol(TextMate.column_number)
      javascript = match[0]
      javascript += '.js' if not javascript =~ /\.js$/
      # If there is no leading slash, assume it's a js from the public/javascripts dir
      public_file = javascript[0..0] == "/" ? javascript[1..-1] : "javascripts/#{javascript}"
      TextMate.open File.join(current_file.rails_root, 'public', public_file)
    else
      puts "No javascript identified"
    end

  # Example: <link href="/stylesheets/application.css">
  # Example: @import url(/stylesheets/conferences.css);
  when /\<link.+href=['"](.+\.css)['"]/, /\@import.+url\((.+\.css)\)/
    stylesheet = $1
    if stylesheet =~ %r{^https?://}
      TextMate.open_url stylesheet
    else
      full_path = File.join(current_file.rails_root, 'public', stylesheet[1..-1])
      TextMate.open full_path
    end

  # Example: <%= stylesheet_link_tag 'application' %>
  when /(require_stylesheet|stylesheet_link_tag)\b/
    if match = TextMate.current_line.unstringify_hash_arguments.find_nearest_string_or_symbol(TextMate.column_number)
      stylesheet = match[0]
      stylesheet += '.css' if not stylesheet =~ /\.css$/
      # If there is no leading slash, assume it's a js from the public/javascripts dir
      public_file = stylesheet[0..0] == "/" ? stylesheet[1..-1] : "stylesheets/#{stylesheet}"
      TextMate.open File.join(current_file.rails_root, 'public', public_file)
    else
      puts "No stylesheet identified"
    end
  
  else
    puts "No 'go to file' directives found on this line."
    # Do nothing -- beep?
end
