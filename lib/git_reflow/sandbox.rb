require "thor/actions"
require "thor/shell/color"

module GitReflow
  module Sandbox
    include Thor::Actions
    extend self

    def shell
      @shell ||= Thor::Shell::Color.new
    end

    def run_command_with_label(command, options = {})
      shell.say_status :info, command, (options.delete(:color) || :green)
      run command, options
    end
  end
end
