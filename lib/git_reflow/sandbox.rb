module GitReflow
  module Sandbox
    extend self

    COLOR_FOR_LABEL = {
      notice:         :yellow,
      info:           :yellow,
      error:          :red,
      deliver_halted: :red,
      review_halted:  :red,
      success:        :green,
      plain:          :white
    }

    class CommandError < StandardError;
      attr_reader :output
      def initialize(output, *args)
        @output = output
        super(*args)
      end
    end

    def run(command, options = {})
      options = { loud: true, blocking: true, raise: false }.merge(options)

      GitReflow.logger.debug "Running... #{command}"

      if options[:with_system] == true
        system(command)
      else
        output = %x{#{command}}

        if !$?.success?
          raise CommandError.new(output, "\"#{command}\" failed to run.") if options[:raise] == true
          abort "\"#{command}\" failed to run." if options[:blocking] == true
        end

        puts output if options[:loud] == true
        output
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
