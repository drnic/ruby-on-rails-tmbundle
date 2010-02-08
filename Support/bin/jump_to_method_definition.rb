#!/usr/bin/env ruby

require 'rails_bundle_tools'
require 'fileutils'
require 'rubygems'

@original_term = ENV['TM_SELECTED_TEXT'] || ENV['TM_CURRENT_WORD']
@term = Regexp.escape(@original_term)
@found = false
@root = RailsPath.new.rails_root

def find_in_file_or_directory(file_or_directory, match_string)
  match_string.gsub!("'","'\"'\"'")
  file_or_directory = "#{file_or_directory}/**/*.rb" if File.directory?(file_or_directory)
  found = `grep -RnPH '#{match_string}' #{file_or_directory} 2>/dev/null`
  next if found.empty?
  filename, line_number = found.split('\n').first.split(':')
  TextMate.open(File.join(filename), line_number.to_i - 1)
  TextMate.exit_show_tool_tip("Found definition for '#{@original_term}' in #{filename}")
  @found = true
end

# First, if this is a route, we know this is in routes.rb
if path = @term.match(/(new_|edit_)?(.*?)_(path|url)/)
  path = path[2].split('_').first
  filename = File.join(@root,"config","routes.rb")
  find_in_file_or_directory(filename, "[^\.].resource[s]? (:|')#{path}(s|es)?[']?")
end

# Second, search the local project for any potentially matching method.
find_in_file_or_directory(@root, "^\s*def #{@term}([\(]{1}[^\)]*[\)]{1}\s*$|\s*$)") 
find_in_file_or_directory(@root, "^\s*(belongs_to|has_many|has_one|has_and_belongs_to_many|scope|named_scope) :#{@term}[\,]?")

# Third, search the Gems directory, pulling only the most recent gems.
Gem.latest_load_paths.each do |directory|
  find_in_file_or_directory(directory, "^\s*def #{@term}([\(]{1}[^\)]*[\)]{1}\s*$|\s*$)")
end

# Alas, this is nowhere that we can determine.
if !@found
  TextMate.exit_show_tool_tip("Could not find definition for '#{@term}'")
end