require "thor/actions"
require "thor/shell/color"

module GitReflow
  module Sandbox
    include Thor::Actions
    include Thor::Shell::Color
    extend self

    def run_command_with_label(command, options = {})
      say_status :info, command, (options.delete(:color) || :green)
      run command, options
    end

  end
end
