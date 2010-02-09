#!/usr/bin/env ruby

require 'rails_bundle_tools'
require 'fileutils'
require 'rubygems'
require "#{ENV['TM_SUPPORT_PATH']}/lib/tm/htmloutput"

@original_term = ENV['TM_SELECTED_TEXT'] || ENV['TM_CURRENT_WORD']
@term = Regexp.escape(@original_term)
@found = []
@root = RailsPath.new.rails_root
DEF_REGEX = "^\s*def (self\.)?#{@term}([\(]{1}[^\)]*[\)]{1}\s*$|\s*$)"
SYMBOL_REGEX = "^\s*(belongs_to|has_many|has_one|has_and_belongs_to_many|scope|named_scope) :#{@term}[\,]?"

def find_in_file_or_directory(file_or_directory, match_string)
  if File.directory?(file_or_directory)
    Dir.glob(File.join(file_or_directory,'**','*.rb')).each do |file|
      find_in_file(file, match_string)
    end
  else
    find_in_file(file_or_directory, match_string)
  end
end

def find_in_file(file, match_string)
  begin
    File.open(file) do |f|
      f.each_line do |line|
        @found << {:filename => f.path, :line_number => f.lineno, :line => line.strip} if line.match(match_string)
      end
    end
  rescue Errno::ENOENT
    return false
  end
end

# First, search the local project for any potentially matching method.
find_in_file_or_directory(@root, DEF_REGEX) 
find_in_file_or_directory(@root, SYMBOL_REGEX)

# Second, if this is a route, we know this is in routes.rb
if path = @term.match(/(new_|edit_)?(.*?)_(path|url)/)
  path = path[2].split('_').first
  filename = File.join(@root,"config","routes.rb")
  find_in_file_or_directory(filename, "[^\.].resource[s]? (:|')#{path}(s|es)?[']?")
end


# Third, search the Gems directory, pulling only the most recent gems, but only if we haven't yet found a match.
Gem.latest_load_paths.each do |directory|
  find_in_file_or_directory(directory, DEF_REGEX)
end

# Render results sensibly.
if @found.empty?
  TextMate.exit_show_tool_tip("Could not find definition for '#{@original_term}'")
elsif @found.size == 1  
  TextMate.open(File.join(@found[0][:filename]), @found[0][:line_number] - 1)
  TextMate.exit_show_tool_tip("Found definition for '#{@original_term}' in #{@found[0][:filename].gsub("#{@root}/",'')}")
else
  TextMate::HTMLOutput.show(
    :title      => "Definitions for #{@original_term}",
    :subtitle   => "#{@found.size} Definitions Found"
  ) do |io|
    io << "<div class='executor'><table border='0' cellspacing='5' cellpading'0'>" 
    io << "<thead><td><h4>Location</h4></td><td><h4>Line</h4></td><td><h4>Definition</h4></td></thead><tbody>"
    @found.each do |location|
      io << "<tr><td><a class='near' href='txmt://open?url=file://#{location[:filename]}&line=#{location[:line_number]}'>#{location[:filename].gsub("#{@root}/",'')}</a></td>"
      io << "<td>#{location[:line_number]}</td>"
      io << "<td><strong>#{location[:line].gsub(/(def |named_scope \:|scope \:|has_many \:|has_one \:|belongs_to \:|has_and_belongs_to_many \:)/,'')}</strong><td?</tr>"
    end
    io << "</tbody></table></div>"
  end
  TextMate.exit_show_html
end