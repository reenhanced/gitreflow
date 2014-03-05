
module GitReflow
  module Sandbox
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def run(command, options = {})
        options = { loud: true }.merge(options)

        if options.delete(:loud)
          puts `#{command}`
        else
          `#{command}`
        end
      end

      def run_command_with_label(command, options = {})
        label_color = options.delete(:color) || :green
        puts command.colorize(label_color)
        run(command)
      end
    end
  end
end
