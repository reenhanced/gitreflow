module GitReflow
  module Sandbox
    extend self

    COLOR_FOR_LABEL = {
      notice:         :yellow,
      error:          :red,
      deliver_halted: :red,
      success:        :green
    }

    def run(command, options = {})
      options = { loud: true }.merge(options)

      if options[:with_system] == true
        system(command)
      elsif options[:loud] == true
        output = `#{command}`
        puts output
        output
      else
        `#{command}`
      end
    end

    def run_command_with_label(command, options = {})
      label_color = options.delete(:color) || :green
      puts command.colorize(label_color)
      run(command, options)
    end

    def say(message, label_type = :plain)
      if COLOR_FOR_LABEL[label_type]
        puts "[#{ label_type.to_s.gsub('_', ' ').colorize(COLOR_FOR_LABEL[label_type]) }] #{message}"
      else
        puts message
      end
    end

    # WARNING: this currently only supports OS X and UBUNTU
    def ask_to_open_in_browser(url)
      if RUBY_PLATFORM =~ /darwin|linux/i
        open_in_browser = ask "Would you like to open it in your browser? "
        if open_in_browser =~ /^y/i
          if RUBY_PLATFORM =~ /darwin/i
            # OS X
            run "open #{url}"
          else
            # Ubuntu
            run "xdg-open #{url}"
          end
        end
      end
    end
  end
end
