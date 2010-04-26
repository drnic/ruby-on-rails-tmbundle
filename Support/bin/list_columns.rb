#!/usr/bin/env ruby -W0

require 'rubygems'
require "yaml"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/ui"

PROJECT    = ENV['TM_PROJECT_DIRECTORY']
CACHE_DIR  = File.expand_path("tmp/textmate/", PROJECT)
CACHE_FILE = File.join(CACHE_DIR, "cache.yml")

def load_and_cache_all_models
  begin
    require "#{ENV['TM_SUPPORT_PATH']}/lib/progress"
    cache = {}

    File.delete(CACHE_FILE) if File.exists?(CACHE_FILE)

    TextMate.call_with_progress(:title => "Contacting database", :message => "Fetching database schema…") do
      require "#{PROJECT}/config/environment"

      Dir.glob(Rails.root.join("app/models/*.rb")) do |file|
        klass = File.basename(file, '.*').camelize.constantize rescue nil
        
        if klass and klass.class == Class and klass.ancestors.include?(ActiveRecord::Base)
          cache[klass.name.underscore] = { 
            :associations => klass.reflections.stringify_keys.keys, 
            :columns      => klass.column_names 
          } rescue nil
        end
      end
    end
    
  rescue Exception => e
    TextMate::UI.tool_tip(e.message)
  ensure
    File.open(CACHE_FILE, 'w') { |out| YAML.dump(cache, out ) }
    return cache
  end
end

def show_options
  begin
    Dir.mkdir(CACHE_DIR) unless File.exists?(CACHE_DIR)
    cache = if File.exist?(CACHE_FILE)
      # TODO: Verificar se houve alguma atualização
      YAML.load(File.read(CACHE_FILE))
    else
      load_and_cache_all_models
    end

    word = ENV['TM_CURRENT_WORD'].scan(/\w*/).select { |x| !x.empty? }.last
    if word.nil? || word.empty?
      TextMate::UI.tool_tip("Place cursor on class name (or variation) to show its schema")
      exit
    end

    require 'active_support/inflector'
    klass = word.singularize.underscore

    if cache[klass]
      columns      = cache[klass][:columns]
      associations = cache[klass][:associations]

      options = associations + ["---"] + columns + ["---", "Reload..."]
      selected = TextMate::UI.menu(options)
      return if selected.nil?
      
      if options[selected] == "Reload..."
        $".delete_if { |x| x.start_with?('active_support') }
        load_and_cache_all_models
        show_options
      else
        STDOUT << options[selected]
      end
    else
      TextMate::UI.tool_tip("'#{klass}' is not an Active Record derived class or was not recognised as a class")
    end

  rescue Exception => e
    TextMate::UI.tool_tip(e.message)
  end
end

show_options