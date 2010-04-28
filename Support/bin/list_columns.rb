#!/usr/bin/env ruby -W0

require "yaml"
require 'rails_bundle_tools'

CACHE_DIR  = File.expand_path("tmp/textmate/", TextMate.project_directory)
CACHE_FILE = File.join(CACHE_DIR, "cache.yml")

RELOAD_MESSAGE = "Reload database schema…"
LINE = "---"

def load_and_cache_all_models
  begin
    require "#{ENV['TM_SUPPORT_PATH']}/lib/progress"
    cache = {}

    File.delete(CACHE_FILE) if File.exists?(CACHE_FILE)

    TextMate.call_with_progress(:title => "Contacting database", :message => "Fetching database schema…") do
      require "#{TextMate.project_directory}/config/environment"

      Dir.glob(Rails.root.join("app/models/*.rb")) do |file|
        klass = File.basename(file, '.*').camelize.constantize rescue nil
      
        if klass and klass.class == Class and klass.ancestors.include?(ActiveRecord::Base)
          cache[klass.name.underscore] = { 
            :associations => klass.reflections.stringify_keys.keys,
            :columns      => klass.column_names
          } rescue nil
        end
      end
      
      File.open(CACHE_FILE, 'w') { |out| YAML.dump(cache, out ) }
    end
    
  rescue Exception => e
    @error = "Fix it: #{e.message}"
  ensure
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
      return TextMate::UI.tool_tip("Place cursor on class name (or variation) to show its schema")
    end

    klass = Inflector.singularize(Inflector.underscore(word))

    if cache[klass]
      columns      = cache[klass][:columns]
      associations = cache[klass][:associations]

      options = associations + [LINE] + columns + [LINE, RELOAD_MESSAGE]
      selected = TextMate::UI.menu(options)
      return if selected.nil?
      
      if options[selected] == RELOAD_MESSAGE
        load_and_cache_all_models
        show_options
      else
        STDOUT << options[selected]
      end
    else
      options = [
        @error || "'#{Inflector.camelize(klass)}' is not an Active Record derived class or was not recognised as a class.", 
        LINE, 
        RELOAD_MESSAGE
      ]
      selected = TextMate::UI.menu(options)
      return if selected.nil?

      if options[selected] == RELOAD_MESSAGE
        load_and_cache_all_models
        show_options
      else
        if @error && @error =~ /^#{TextMate.project_directory}(.+?)[:]?(\d+)/
          TextMate.open(File.join(TextMate.project_directory, $1), $2.to_i)
        else
          klass_file = File.join(TextMate.project_directory, "/app/models/#{klass}.rb")
          TextMate.open(klass_file) if File.exist?(klass_file)
        end
      end
    end

  rescue Exception => e
    TextMate::UI.tool_tip(e.message)
  end
end

show_options