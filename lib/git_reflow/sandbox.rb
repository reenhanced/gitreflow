module GitReflow
  module Sandbox
    extend self

    COLOR_FOR_LABEL = {
      notice:         :yellow,
      error:          :red,
      deliver_halted: :red,
      review_halted:  :red,
      success:        :green,
      plain:          :white
    }

    def run(command, options = {})
      options = { loud: true, blocking: true }.merge(options)

      if options[:with_system] == true
        system(command)
      else
        output = %x{#{command}}

        if options[:blocking] == true && !$?.success?
          abort "\`#{command}\` failed to run."
        else
          puts output if options[:loud] == true
          output
        end
      end
    end

    def run_command_with_label(command, options = {})
      label_color = options.delete(:color) || :green
      puts command.colorize(label_color)
      run(command, options)
    end

    def say(message, label_type = :plain)
      if COLOR_FOR_LABEL[label_type]
        label = (label_type.to_s == "plain") ? "" : "[#{ label_type.to_s.gsub('_', ' ').colorize(COLOR_FOR_LABEL[label_type]) }] "
        puts "#{label}#{message}"
      else
        puts message
      end
    end

  end
end
