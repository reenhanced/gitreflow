require "thor/actions"
require "thor/shell/color"

module GitReflow
  module Sandbox
    include Thor::Actions
    extend self

    class Runner < Thor
      include Thor::Actions
    end

    def runner
      @command_line_runner = Runner.new
    end

    def run(command, config = {})
      runner.run(command, config)
    end

    def shell
      @shell ||= Thor::Shell::Color.new
    end

    def run_command_with_label(command, options = {})
      shell.say_status :info, command, (options.delete(:color) || :green)
      run command, options
    end
  end
end
