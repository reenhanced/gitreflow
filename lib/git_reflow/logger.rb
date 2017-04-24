require 'git_reflow/config'
require 'logger'

module GitReflow
  class Logger < ::Logger
    DEFAULT_LOG_FILE = "/tmp/git-reflow.log"
    COLORS = {
      "FATAL" => :red,
      "ERROR" => :red,
      "WARN"  => :orange,
      "INFO"  => :yellow,
      "DEBUG" => :white,
    }

    def initialize(*args)
      log_file = args.shift || log_file_path
      args.unshift(log_file)
      super(*args)
      @formatter = SimpleFormatter.new
    end

    # Simple formatter which only displays the message.
    class SimpleFormatter < ::Logger::Formatter
      # This method is invoked when a log event occurs
      def call(severity, timestamp, progname, msg)
        if $stdout.tty?
          "#{severity.colorize(COLORS[severity])}: #{String === msg ? msg : msg.inspect}\n"
        else
          "#{severity}: #{String === msg ? msg : msg.inspect}\n"
        end
      end
    end

    private

    def log_file_path
      return @log_file_path if "#{@log_file_path}".length > 0

      # Here we have to run the command in isolation to avoid a recursive loop
      # to log this command run to fetch the config setting.
      configured_log_file_path = %x{git config --get reflow.log-file-path}

      if configured_log_file_path.length > 0
        @log_file_path = configured_log_file_path
      else
        @log_file_path = DEFAULT_LOG_FILE
      end
    end

  end
end
