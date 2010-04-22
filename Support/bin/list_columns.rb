#!/usr/bin/env ruby

require "yaml"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/ui"

begin
  PROJECT    = ENV['TM_PROJECT_DIRECTORY']
  CACHE_DIR  = File.expand_path("tmp/textmate/", PROJECT)
  CACHE_FILE = File.join(CACHE_DIR, "cache.yml")

  Dir.mkdir(CACHE_DIR) unless File.exists?(CACHE_DIR)
  cache = if File.exist?(CACHE_FILE)
    YAML.load(File.read(CACHE_FILE)) || {}
  else
    {}
  end

  word = ENV['TM_CURRENT_WORD'].scan(/\w*/).select { |x| !x.empty? }.last

  if word.nil? || word.empty?
    TextMate::UI.tool_tip("Place cursor on class name (or variation) to show its schema")
    exit
  end

  if cache[word] && cache[word][:expire_after] > Time.now
    columns      = cache[word][:columns] || []
    associations = cache[word][:associations] || []
    
    options = associations + ["---"] + columns
    selected = TextMate::UI.menu(options)
    STDOUT << options[selected] if selected
  else
    require "#{PROJECT}/config/environment"

    klass = word.camelcase.singularize.constantize rescue nil
    if klass and klass.class == Class and klass.ancestors.include?(ActiveRecord::Base)
      columns      = klass.column_names
      associations = klass.reflections.stringify_keys.keys
      
      cache[word] = { :associations => associations, :columns => columns, :expire_after => 1.hour.since }

      File.open(CACHE_FILE, 'w') { |out| YAML.dump(cache, out ) }

      options = associations + ["---"] + columns
      selected = TextMate::UI.menu(options)
      STDOUT << options[selected] if selected

    elsif klass and klass.class == Class and not klass.ancestors.include?(ActiveRecord::Base)
      TextMate::UI.tool_tip("'#{word}' is not an Active Record derived class")
    else
      TextMate::UI.tool_tip("'#{word}' was not recognised as a class")
    end
  end
rescue Exception => e
  TextMate::UI.tool_tip(e.message)
end
