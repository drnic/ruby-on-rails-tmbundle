#!/usr/bin/env ruby

require 'rails_bundle_tools'
require 'fileutils'
require 'rubygems'
require "#{ENV['TM_SUPPORT_PATH']}/lib/tm/htmloutput"

class FindMethod
  attr_accessor :found_methods, :root, :filepath, :term
  
  def initialize(term, filepath = RailsPath.new)
    @term = term
    @term = @term + $1 if TextMate.current_line.match(Regexp.new(Regexp.escape(@term) + '(!|\?)'))
    @found_methods = []
    @filepath = filepath
    @root = RailsPath.new.rails_root || TextMate.directory
    self.find
    self.render_results
  end
  
  def method_regexp_for(term)
    "^\\s*def (self\.)?#{Regexp.escape(term)}([\(]{1}[^\)]*[\)]{1}\\s*$|\\s*$)"
  end

  def association_regexp_for(term)
    "^\\s*(belongs_to|has_many|has_one|has_and_belongs_to_many|scope|named_scope) :#{Regexp.escape(term)}[\,]?"
  end

  def class_or_module_regexp_for(term)
    "^\\s*(class|module)[^<]*[\\s:]#{Regexp.escape(term)}[\\s:\#\n]*[<$\n]"
  end

  def variable_regexp_for(term)
    "#{Regexp.escape(term)}\\s="
  end
  
  def path_regexp_for(term)
    "[^\.].resource[s]? (:|')#{term}(s|es)?[']?"
  end

  def find_in_file(file, match_string)
    begin
      File.open(file) do |f|
        f.each_line do |line|
          @found_methods << {:filename => f.path, :line_number => f.lineno, :line => line.strip} if line.match(match_string)
        end
      end
    rescue Errno::ENOENT
      return false
    end
  end
  
  def found_in_file(file, match_string)
    begin
      File.open(file) do |f|
        f.each_line do |line|
          return f.lineno if line.match(match_string)
        end
      end
    rescue Errno::ENOENT
      return false
    end
  end

  def find_in_directory(directory, match_string)
    Dir.glob(File.join(directory,'**','*.rb')).each do |file|
      find_in_file(file, match_string)
    end
  end

  def find_in_gems(match_string)
    Gem.latest_load_paths.each do |directory|
      find_in_directory(directory, match_string)
    end
  end

  def find_class_or_module
    match = class_or_module_regexp_for(@term)
    find_in_directory(@root, match)
    find_in_gems(match)
  end
  
  def find_variable
    @term = "@#{@term}"
    if @filepath.file_type == :view
      probable_controller = File.join(@root,"app","controllers","#{@filepath.controller_name}_controller.rb")
      if File.file?(probable_controller)
        find_in_file(File.join(@root,"app","controllers","#{@filepath.controller_name}_controller.rb"), variable_regexp_for(@term))
        action = @filepath.action_name
        if line_number = found_in_file(probable_controller, method_regexp_for(action))
          @found_methods = [@found_methods.sort {|m1, m2| (line_number - m1[:line_number]).abs <=> (line_number - m2[:line_number]).abs}.first]
        end
      end
    else
      find_in_file(TextMate.filepath, variable_regexp_for(@term))
    end
  end
  
  def find_method    
    find_in_directory(@root, method_regexp_for(@term))
    find_in_directory(File.join(@root,'app','models'), association_regexp_for(@term))

    if path = @term.match(/(new_|edit_)?(.*?)_(path|url)/) # This might be a magic method from routes, so check routes.rb for sensible permutations
      path = path[2].split('_').first
      find_in_file(File.join(@root,"config","routes.rb"), path_regexp_for(path))
    end

    find_in_gems(method_regexp_for(@term))
  end
  
  def find
    case
    when @term=~/^[A-Z]/ then find_class_or_module # First, if this starts with a capital, it's probably a class or a module
    when TextMate.current_line.match(Regexp.escape('@' + @term )) then find_variable # Second, if this starts with a @, it's an instance variable
    else find_method # Otherwise, try to find it as a method
    end
  end
  
  def render_results
    @found_methods.uniq!
    if @found_methods.empty?
      TextMate.exit_show_tool_tip("Could not find definition for '#{@term}'")
    elsif @found_methods.size == 1  
      TextMate.open(File.join(@found_methods[0][:filename]), @found_methods[0][:line_number] - 1)
      TextMate.exit_show_tool_tip("Found definition for '#{@term}' in #{@found_methods[0][:filename].gsub("#{@root}/",'')}")
    else
      TextMate::HTMLOutput.show(
        :title      => "Definitions for #{@term}",
        :sub_title  => "#{@found_methods.size} Definitions Found"
      ) do |io|
        io << "<div class='executor'><table border='0' cellspacing='5' cellpading'0'>"
        io << "<pre>Found #{@found_methods.size} definitions for #{@term}:</pre>"
        io << "<thead><td><h4>Location</h4></td><td><h4>Line</h4></td><td><h4>Definition</h4></td></thead><tbody>"
        @found_methods.each do |location|
          io << "<tr><td><a class='near' href='txmt://open?url=file://#{location[:filename]}&line=#{location[:line_number]}'>#{location[:filename].gsub("#{@root}/",'')}</a></td>"
          io << "<td>#{location[:line_number]}</td>"
          io << "<td><strong>#{location[:line].strip}</strong><td?</tr>"
        end
        io << "</tbody></table></div>"
      end
      TextMate.exit_show_html
    end
  end
  
end

FindMethod.new(TextMate.selected_text || TextMate.current_word)