#!/usr/bin/env ruby

require "yaml"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/ui"

CACHE_DIR = File.expand_path("tmp/textmate/", ENV['TM_PROJECT_DIRECTORY'])
CACHE_FILE = File.join(CACHE_DIR, "cache.yml")

begin
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

  if cache[word] && cache["time_#{word}"] > (Time.now - 3600)
    options = cache[word]
    selected = TextMate::UI.menu(options)
    STDOUT << options[selected] if selected
  else
    require "#{ENV['TM_PROJECT_DIRECTORY']}/config/environment"

    klass = word.camelcase.singularize.constantize rescue nil
    if klass and klass.class == Class and klass.ancestors.include?(ActiveRecord::Base)
      columns = klass.columns_hash
      options = columns.map { |col, attrs| col }.sort

      cache["time_#{word}"] = Time.now
      cache[word] = options
      File.open(CACHE_FILE, 'w') { |out| YAML.dump(cache, out ) }

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
