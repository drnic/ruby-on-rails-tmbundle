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

def args_except_hash(string)
  string.gsub(/,?[^,]*=>[^,]*/, '').split(',')
end

# TODO: Make string_near_column work for :symbols also.  Optimize with Regexp?
def string_near_column(string, col)
  start=col-1
  while start >= 0 && string[start] != ?' && string[start] != ?" do
    start -= 1
  end
  if start >= 0
    term=string[start]
    string = string[start+1,string.length-start]
    if (stop = string.index(term))
      other = string.index(term == ?' ? ?": ?')
      if (other.nil? || other > stop)
  string[0,stop]
      end
    end
  end
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

def find_or_name_view_file(filename, current_file)
  # Look for a view file with any of the following extensions
  extensions = %w(rhtml rxhtml rxml rjs)
  file_exists = false
  extensions.each do |e|
    filename_with_extension = filename + "." + e
    view_file = File.join(current_file.rails_root, 'app', 'views', current_file.modules, current_file.controller_name, filename_with_extension)
    return view_file if File.exist?(view_file)
  end
  
  # No view files found, so ask for the name of a new one
  if filename = TextMate.input("Enter the name of the new view file:", filename + '.rhtml')
    view_file = File.join(current_file.rails_root, 'app', 'views', current_file.modules, current_file.controller_name, filename)
    # Create the file and notify TextMate of its existence
    f = File.open(view_file, "w"); f.close
    # FIXME: For some reason the following line freezes TextMate
    # TextMate.refresh_project_drawer
    return view_file
  else
    return nil
  end
end

current_file = RailsPath.new

# If the current line contains "render :partial", then open the partial.
case TextMate.current_line

  # Example: render :partial => 'account/login'
  when /render[\s\(].*:partial\s*=>\s*['"](.+?)['"]/
    partial_name = $1
    modules = current_file.modules
  
    # Check for absolute path to partial
    if partial_name.include?('/')
      pieces = partial_name.split('/')
      partial_name = pieces.pop
      modules = pieces
    end

    partial = File.join(current_file.rails_root, 'app', 'views', modules, current_file.controller_name, "_#{partial_name}.rhtml")
    TextMate.open(partial)

  # Example: render :action => 'login'
  when /render[\s\(].*:action\s*=>\s*['"](.+?)['"]/
    action = $1
    if current_file.file_type == :controller
      if search = current_file.buffer.find(:direction => :backwards) { /def\s+#{action}\b/ }
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

  # Other checks...
  else
    # If there's nothing specific on the current line, then try something a little more "out of the box"
    
    # Controllers can go to Views or Helpers
    if current_file.file_type == :controller
      # Jump to the view that corresponds with this action
      if result = current_file.buffer.find_method(:direction => :backwards)
        if view_file = find_or_name_view_file(result[0], current_file)
          TextMate.open view_file
        end
      else
        # Try to find a corresponding helper file instead of an action or view
        helper_file = File.join(current_file.rails_root, 'app', 'helpers', current_file.modules, current_file.controller_name + '_helper.rb')
        TextMate.open helper_file
      end
    
    # Helpers can go to Controllers
    elsif current_file.file_type == :helper
      controller_file = current_file.rails_path_for(:controller)
      TextMate.open controller_file
    
    # ActionMailer Models can go to Views
    elsif current_file.file_type == :model
      if current_file.buffer.text.include?("ActionMailer::Base")
        if result = current_file.buffer.find_method(:direction => :backwards)
          full_path = File.join(current_file.rails_root, 'app', 'views', current_file.model_name, result[0] + ".rhtml")
          TextMate.open full_path
        else
          TextMate.message "No action found"
        end
      else
        TextMate.message "Don't know where to go from a non-actionmailer model"
      end
    
    # Views can go to Controllers or ActionMailer Models
    elsif current_file.file_type == :view
      # Jump to the controller action that corresponds with this view
      full_path =
        File.join(current_file.rails_root, 'app', 'controllers',
          current_file.modules.join('/'),
          current_file.controller_for_view + '_controller.rb')
      
      if !File.exist?(full_path)
        # Maybe it's an ActionMailer Model?
        full_path =
          File.join(current_file.rails_root, 'app', 'models',
            current_file.controller_for_view + '.rb')
      end
      
      if !File.exist?(full_path)
        TextMate.message "Couldn't find a controller or ActionMailer model for this view"
        TextMate.exit_discard
      end
      
      lines = IO.read(full_path).to_a
      line_number = nil
      for i in 0..(lines.size)
        if lines[i] =~ %r{def\s+(#{current_file.view_name})}
          line_number = i + 1
          break
        end
      end
    
      TextMate.open full_path, line_number
    else
      TextMate.message("Nowhere to go.")
    end
end
