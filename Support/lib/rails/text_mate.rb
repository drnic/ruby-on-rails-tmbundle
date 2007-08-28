# Copyright:
#   (c) 2006 syncPEOPLE, LLC.
#   Visit us at http://syncpeople.com/
# Author: Duane Johnson (duane.johnson@gmail.com)
# Description:
#   Helper module for accesing TextMate facilities such as environment variables.

module TextMate
  class <<self
    # TextMate shell script exit codes.
    # See /Applications/TextMate.app/Contents/SharedSupport/Support/lib/bash_init.sh for a comprehensive list
    def exit_discard; exit 200 end
    def exit_replace_text; exit 201; end
    def exit_replace_document; exit 202 end
    def exit_insert_text; exit 203 end
    def exit_insert_snippet; exit 204 end
    def exit_show_html; exit 205 end
    def exit_show_tool_tip; exit 206 end
    def exit_create_new_document; exit 207 end

    def open_url(url)
      `open "#{url}"`
    end

    # Open a file in textmate using the txmt:// protocol.  Uses 0-based line and column indices.
    def open(filename, line_number = nil, column_number = nil)
      filename = filename.filepath if filename.is_a? RailsPath
      options = []
      options << "url=file://#{filename}"
      options << "line=#{line_number + 1}" if line_number
      options << "column=#{column_number + 1}" if column_number
      open_url "txmt://open?" + options.join("&")
    end

    # Switching away from and then back to TextMate will automatically cause it to refresh the project drawer
    def refresh_project_drawer
      `osascript -e 'tell application "Dock" to activate'; osascript -e 'tell application "TextMate" to activate'`
    end

    # Always return something, or nil, for selected_text
    def selected_text
      env(:selected_text)
    end
    
    # Make line_number 0-base index
    def line_number
      env(:line_number).to_i - 1
    end
    
    # Make column_number 0-base as well
    def column_number
      env(:column_number).to_i - 1
    end

    def project_directory
      env(:project_directory)
    end
    
    def env(var)
      ENV['TM_' + var.to_s.upcase]
    end
    
    # Forward to the TM_* environment variables if method is missing.  Some useful variables include:
    #   selected_text, current_line, column_number, line_number, support_path
    def method_missing(method, *args)
      if value = env(method)
        return value
      else
        super(method, *args)
      end
    end

    # TODO: Move cocoa dialog stuff to its own class or module
    
    def cocoa_dialog_command
      "#{support_path}/bin/CocoaDialog.app/Contents/MacOS/CocoaDialog"
    end
    
    # See http://cocoadialog.sourceforge.net/documentation.html for documentation
    def cocoa_dialog(command, options = {})
      options_list = []
      options.each_pair do |k, v| 
        k = k.to_s.gsub('_', '-')
        value = v.is_a?(Array) ? %Q{"#{v.join('" "')}"} : "\"#{v}\""
        if v
          if v.is_a? TrueClass
            options_list << "--#{k}"
          else
            options_list << "--#{k} #{value}"
          end
        end
      end
      dialog_command = "\"#{cocoa_dialog_command}\" #{command} #{options_list.join(' ')}"
      # $logger.debug "Dialog command: #{dialog_command}"
      `#{dialog_command}`.to_a.map { |v| v.strip }
    end
    
    # Shows an information bubble with a nice gradient background
    #
    def message(text, options = {})
      options = {:title => "Message", :informative_text => text, :button1 => "Ok"}.update(options)
      return cocoa_dialog('msgbox', options)[0] == "1"
    end

    def textbox(informative_text, text, options = {})
      options = {:title => "Message", :informative_text => informative_text, :text => text, :button1 => "Ok"}.update(options)
      return cocoa_dialog('textbox', options)[0] == "1"
    end

    def message_yes_no_cancel(text, options = {})
      options = {:title => "Message", :text => text}.update(options)
      return cocoa_dialog('yesno-msgbox', options)[0] == "1"
    end

    def message_ok_cancel(text, informative_text = nil, options = {})
      options = {:title => "Message", :text => text, :informative_text => informative_text}.update(options)
      return cocoa_dialog('ok-msgbox', options)[0] == "1"
    end

    def input(text, default_text = "", options = {})
      options = {:title => "Input", :informative_text => text, :text => default_text}.update(options)
      button, text = cocoa_dialog('standard-inputbox', options)
      if button == '1'
        return text.strip
      else
        return nil
      end
    end
    
    def choose(text, choices = ["none"], options = {})
      options = {:title => "Choose", :text => text, :items => choices, :button1 => 'Ok', :button2 => 'Cancel'}.update(options)
      button, choice = cocoa_dialog('dropdown', options)
      if button == '1'
        return choice.strip.to_i
      else
        return nil
      end
    end
  end
end


module TextMate

	def TextMate.call_with_progress( args, &block )
		output_filepath	= args[:output_filepath]		# path to open after execution
		
		title			= args[:title] || 'Progress'
		message			= args[:message] || 'Frobbing the widget...'
		
		cocoa_dialog	= "#{ENV['TM_SUPPORT_PATH']}/bin/CocoaDialog.app/Contents/MacOS/CocoaDialog"

		tempdir = "/tmp/TextMate_progress_cmd_tmp.#{$PID}"
		Dir.mkdir(tempdir)
		Dir.chdir(tempdir)
		pipe = IO.popen( %Q("#{cocoa_dialog}" progressbar --indeterminate --title "#{title}" --text "#{message}"), "w+")
		begin
			pipe.puts ""
			data = block.call
			puts data
		ensure
			pipe.close
			%x{rm -rf "#{tempdir}"}
		end

		sleep 0.1
		
	end

end
