# Copyright:
#   (c) 2006 syncPEOPLE, LLC.
#   Visit us at http://syncpeople.com/
# Author: Duane Johnson (duane.johnson@gmail.com)
# Description:
#   Makes analyzing of a Rails path + filename easier.

require 'rails/misc'
require 'rails/text_mate'
require 'rails/buffer'

module AssociationMessages
  # Return associated_with_*? methods
  def method_missing(method, *args)
    case method.to_s
    when /^associated_with_(.+)\?$/
      return associations[$1.to_sym].include?(file_type)
    else
      super(method, *args)
    end
  end

  @@associations = {
    :controller => [:view, :helper, :functional_test, :javascript, :stylesheet],
    :helper => [:controller, :unit_test, :javascript, :stylesheet],
    :view => [:controller, :javascript, :stylesheet, :model],
    :model => [:unit_test, :fixture, :view],
    :fixture => [:unit_test],
    :functional_test => [:controller],
    :unit_test => [:model, :helper],
    :javascript => [:helper, :controller],
    :stylesheet => [:helper, :controller] }

  # Make associations hash publicly available to each object
  def associations; self.class.class_eval("@@associations") end
end

class RailsPath
  attr_reader :filepath

  include AssociationMessages

  def initialize(filepath = TextMate.filepath)
    if filepath[0..0] == '/'
      # Absolute file, treat as is
      @filepath = filepath
    else
      # Relative file, prepend rails_root
      @filepath = File.join(rails_root, filepath)
    end
  end

  def buffer
    @buffer ||= Buffer.new_from_file(self)
  end

  def exists?
    File.file?(@filepath)
  end
  
  def basename
    File.basename(@filepath)
  end
  
  def dirname
    File.dirname(@filepath)
  end

  def touch_directories
    return if dirname[0..0] != '/'
    dirs = dirname[1..-1].split('/')
    for i in 0..(dirs.size)
      new_dir = '/' + File.join(dirs[0..i])
      Dir.mkdir(new_dir) if !File.exist?(new_dir)
    end
  end
  
  # Make sure the file exists by creating it if it doesn't
  def touch
    if !exists?
      touch_directories
      f = File.open(@filepath, "w"); f.close
    end
  end
  
  def controller_name
    name = basename
    # Remove extension
    name.sub!(/\.\w+$/, '')
    # Remove extras
    case file_type
    when :controller then name.sub!(/_controller$/, '')
    when :helper     then name.sub!(/_helper$/, '')
    when :unit_test  then name.sub!(/_test$/, '')
    when :view       then name = dirname.split('/').pop
    when :functional_test then name.sub!(/_controller_test$/, '')
    end
    
    return name
  end
  
  def action_name
    name =
      case file_type
      when :controller, :model
        buffer.find_method(:direction => :backwards).first rescue nil
      when :view
        basename
      when :functional_test
        buffer.find_method(:direction => :backwards).first.sub('^test_', '')
      else nil
      end
    
    return name.sub(/\.\w+$/, '') rescue nil # Remove extension
  end
  
  def rails_root
    return TextMate.project_directory
    # TODO: Look for the root_indicators inside TM_PROJECT_DIRECTORY and return nil if not found

    #self.class.root_indicators.each do |i|
    #  if index = @filepath.index(i)
    #    return @filepath[0...index]
    #  end
    #end
  end

  def file_type
    return @file_type if @file_type
    
    @file_type =
      case @filepath
      when %r{/controllers/(.+_controller\.(rb))$}   then :controller
      when %r{/controllers/(application\.(rb))$}     then :controller
      when %r{/helpers/(.+_helper\.rb)$}             then :helper
      when %r{/views/(.+\.(rhtml|rxml|rxhtml|rjs|erb))$} then :view
      when %r{/models/(.+\.(rb))$}                   then :model
      when %r{/test/fixtures/(.+\.(yml|csv))$}       then :fixture
      when %r{/test/functional/(.+\.(rb))$}          then :functional_test
      when %r{/test/unit/(.+\.(rb))$}                then :unit_test
      when %r{/public/javascripts/(.+\.(js))$}       then :javascript
      when %r{/public/stylesheets/(.+\.(css))$}      then :stylesheet
      else nil
      end
    # Store the tail (modules + file) after the regexp
    # The first set of parens in each case will become the "tail"
    @tail = $1
    # Store the file extension
    @extension = $2
    return @file_type
  end
  
  def tail
    # Get the tail if it's not set yet
    file_type unless @tail
    return @tail
  end
  
  def extension
    # Get the extension if it's not set yet
    file_type unless @extension
    return @extension
  end
  
  # View file that does not begin with _
  def partial?
    file_type == :view and basename !~ /^_/
  end
  
  def modules
    case file_type
    when :view
      @tail.split('/').slice(0...-2)
    else
      @tail.split('/').slice(0...-1)
    end
  end
  
  def controller_name_modified_for(type)
    case type
    when :controller
      if controller_name == 'application'
        controller_name
      else
        controller_name + '_controller'
      end
    when :helper     then controller_name + '_helper'
    when :functional_test then controller_name + '_controller_test'
    when :unit_test  then controller_name + '_test'
    else controller_name
    end
  end

  def default_extension_for(type)
    case type
    when :javascript then '.js'
    when :stylesheet then '.css'
    when :view       then '.rhtml' # Default extension for view
    else '.rb'
    end
  end
  
  def rails_path_for(type)
    return rails_path_for_view if type == :view
    if TextMate.project_directory
      RailsPath.new(File.join(rails_root, stubs[type], modules, controller_name_modified_for(type) + default_extension_for(type)))
    else
      puts "There needs to be a project associated with this file."
    end
  end
  
  def rails_path_for_view
    return nil if action_name.nil?
    
    # Look for a view file with any of the following extensions
    candidate_extensions = %w(rhtml rxhtml rxml rjs)
    file_exists = false
    candidate_extensions.each do |e|
      filename_with_extension = action_name + "." + e
      existing_view = File.join(rails_root, stubs[:view], modules, controller_name, filename_with_extension)
      return RailsPath.new(existing_view) if File.exist?(existing_view)
    end
    default_view = File.join(rails_root, stubs[:view], modules, controller_name, action_name + default_extension_for(:view))
    return RailsPath.new(default_view)
  end
  
  def ask_for_view(default_name = action_name)
    if designated_name = TextMate.input("Enter the name of the new view file:", default_name + default_extension_for(:view))
      view_file = File.join(rails_root, stubs[:view], modules, controller_name, designated_name)
      f = File.open(view_file, "w"); f.close
      # FIXME: For some reason the following line freezes TextMate
      # TextMate.refresh_project_drawer
      return RailsPath.new(view_file)
    end
    return nil
  end
  
  def self.stubs
    { :controller => 'app/controllers',
      :model => 'app/models',
      :helper => '/app/helpers/',
      :view => '/app/views/',
      :config => 'config',
      :lib => 'lib',
      :log => 'log',
      :javascript => 'public/javascripts',
      :stylesheet => 'public/stylesheets',
      :functional_test => 'test/functional',
      :unit_test => 'test/unit',
      :fixture => 'test/fixtures'}
  end
  
  def stubs; self.class.stubs end
    
  def ==(other)
    other = other.filepath if other.respond_to?(:filepath)
    @filepath == other
  end
end