module GitReflow
  module Sandbox
    extend self

    COLOR_FOR_LABEL = {
      notice:         :yellow,
      error:          :red,
      deliver_halted: :red,
      review_halted:  :red,
      success:        :green
    }

    def run(command, options = {})
      options = { loud: true }.merge(options)

      if options[:with_system] == true
        system(command)
      elsif options[:loud] == true
        output = %x{#{command}}
        puts output
        output
      else
        %x{#{command}}
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

  end
end
