#!/usr/bin/env ruby -W0

require "yaml"
require "rails_bundle_tools"
require "progress"
require "current_word"

CACHE_DIR  = File.expand_path("tmp/textmate/", TextMate.project_directory)
CACHE_FILE = File.join(CACHE_DIR, "cache.yml")

RELOAD_MESSAGE = "Reload database schema..."
LINE = "---"

def load_and_cache_all_models
  begin
    cache = {}
    File.delete(CACHE_FILE) if File.exists?(CACHE_FILE)
    
    TextMate.call_with_progress(:title => "Contacting database", :message => "Fetching database schema...") do
      begin
        require "#{TextMate.project_directory}/config/environment"
        
        Dir.glob(File.join(Rails.root, "app/models/*.rb")) do |file|
          klass = File.basename(file, '.*').camelize.constantize rescue nil
      
          if klass and klass.class == Class and klass.ancestors.include?(ActiveRecord::Base)
            cache[klass.name.underscore] = { 
              :associations => klass.reflections.stringify_keys.keys,
              :columns      => klass.column_names
            } rescue nil
          end
        end
      
        File.open(CACHE_FILE, 'w') { |out| YAML.dump(cache, out ) }
      rescue Exception => e
        @error = "Fix it: #{e.message}"
      end
    end
    
  rescue Exception => e
    @error = "Fix it: #{e.message}"
  ensure
    return cache
  end
end

def cache
  return @cache if @cache
  Dir.mkdir(CACHE_DIR) unless File.exists?(CACHE_DIR)
  @cache = File.exist?(CACHE_FILE) ? YAML.load(File.read(CACHE_FILE)) : load_and_cache_all_models
end

def clone_cache(klass, new_word)
  cached_model = cache[klass]
  cache[new_word] = cached_model
  
  File.open(CACHE_FILE, 'w') { |out| YAML.dump(cache, out ) }
end

# Returns the last word before the cursor
# 
def word
  return @word if @word  
  current_word = Word.current_word('a-zA-Z0-9.', :left)

  @separator = current_word.end_with?('.') ? '' : '.'
  @word      = current_word.split('.').last
end

def display_menu(klass)
  columns      = cache[klass][:columns]
  associations = cache[klass][:associations]

  options = associations + [LINE] + columns + [LINE, RELOAD_MESSAGE]
  selected = TextMate::UI.menu(options)
  return if selected.nil?
  
  if options[selected] == RELOAD_MESSAGE
    load_and_cache_all_models
    show_options
  else
    STDOUT << "#{@separator}#{options[selected]}"
  end
end

def rails_present?
  regex = /^Rails (\d\.?){3}(\w+)?$/
  rails_version = "rails -v 2> /dev/null"
  return `#{rails_version}` =~ regex || `bundle exec #{rails_version}` =~ regex
end

def show_options
  begin
    return TextMate::UI.tool_tip("Place cursor on class name (or variation) to show its schema") if word.nil? || word.empty?
    
    # Check if Rails is installed.
    unless rails_present?
      message = "You don't have Rails installed in this gemset."
      
      if File.exists?("#{TextMate.project_directory}/.rvmrc") && 
        if rvm = File.open("#{TextMate.project_directory}/.rvmrc").read
          message += " (#{rvm.sub('rvm use', '').strip})"
        end
      end
      
      return TextMate::UI.tool_tip(message)
    end
    
    klass = Inflector.singularize(Inflector.underscore(word))

    if cache[klass]
      display_menu(klass)
    elsif cache[klass_without_undescore = klass.split('_').last]
      display_menu(klass_without_undescore)
    else
      options = [
        @error || "'#{Inflector.camelize(klass)}' is not an Active Record derived class or was not recognised as a class.", 
        LINE,
        cache.keys.map { |model_name| "Use #{Inflector.camelize(model_name)}..." },
        LINE,
        RELOAD_MESSAGE
      ].flatten
      selected = TextMate::UI.menu(options)
      
      return if selected.nil?

      case options[selected]
      when options.first
        if @error && @error =~ /^#{TextMate.project_directory}(.+?)[:]?(\d+)/
          TextMate.open(File.join(TextMate.project_directory, $1), $2.to_i)
        else
          klass_file = File.join(TextMate.project_directory, "/app/models/#{klass}.rb")
          TextMate.open(klass_file) if File.exist?(klass_file)
        end
      when RELOAD_MESSAGE
        load_and_cache_all_models
        show_options
      else
        klass = Inflector.singularize(Inflector.underscore(options[selected].split[1].delete('...')))
        clone_cache(klass, word)
        display_menu(word)
      end
    end

  rescue Exception => e
    TextMate::UI.tool_tip(e.message)
  end
end

show_options