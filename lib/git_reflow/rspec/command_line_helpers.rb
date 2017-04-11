require "highline"

module GitReflow
  module RSpec
    module CommandLineHelpers

      def stub_command_line
        $commands_ran     = []
        $stubbed_commands = {}
        $output           = []
        $says             = []

        stub_run_for GitReflow
        stub_run_for GitReflow::Sandbox
        stub_run_for GitReflow::Workflow
        stub_run_for GitReflow::Workflows::Core if defined? GitReflow::Workflows

        stub_output_for(GitReflow)
        stub_output_for(GitReflow::Sandbox)
        stub_output_for(GitReflow::Workflow)

        allow_any_instance_of(GitReflow::GitServer::PullRequest).to receive(:printf) do |format, *output|
          $output << Array(output).join(" ")
          output = ''
        end.and_return("")
      end

      def stub_output_for(object_to_stub, method_to_stub = :puts)
        allow_any_instance_of(object_to_stub).to receive(method_to_stub) do |output|
          $output << output
          output = ''
        end
      end

      def stub_run_for(module_to_stub)
        allow(module_to_stub).to receive(:run) do |command, options|
          options = { loud: true, blocking: true }.merge(options || {})
          $commands_ran << Hashie::Mash.new(command: command, options: options)
          ret_value = $stubbed_commands[command] || ""
          command = "" # we need this due to a bug in rspec that will keep this assignment on subsequent runs of the stub
          ret_value
        end
        allow(module_to_stub).to receive(:say) do |output, type|
          $says << {message: output, type: type}
        end
      end

      def reset_stubbed_command_line
        $commands_ran = []
        $stubbed_commands = {}
        $output = []
        $says = []
      end

      def stub_command(command, return_value)
        $stubbed_commands[command] = return_value
        allow(GitReflow::Sandbox).to receive(:run).with(command).and_return(return_value)
      end

      def stub_command_line_inputs(inputs)
        allow_any_instance_of(HighLine).to receive(:ask) do |terminal, question|
        return_value = inputs[question]
        question = ""
        return_value
        end
      end

    end
  end
end

RSpec::Matchers.define :have_run_command do |command, options|
  options = { blocking: true, loud: true }.merge(options || {})

  match do |block|
    block.call
    (
      $commands_ran.include? Hashie::Mash.new(command: command, options: options) or
      $commands_ran.include? Hashie::Mash.new(command: command, options: options.merge({with_system: true}))
    )
  end

  supports_block_expectations

  failure_message do |block|
    "expected to have run the command \`#{command}\` with options \`#{options}\` but instead ran:\n\t#{$commands_ran.inspect}"
  end
end

RSpec::Matchers.define :have_run_command_silently do |command, options|
  options = { blocking: true, loud: false }.merge(options || {})

  match do |block|
    block.call
    $commands_ran.include? Hashie::Mash.new(command: command, options: options)
  end

  supports_block_expectations

  failure_message do |block|
    "expected to have run the command \`#{command}\` silently with options \`#{options}\` but instead ran:\n\t#{$commands_ran.inspect}"
  end
end

RSpec::Matchers.define :have_run_commands_in_order do |commands|
  match do |block|
    block.call
    remaining_commands  = commands
    command_start_index = $commands_ran.find_index {|c| c.command == commands.first }
    return false unless command_start_index

    $commands_ran.each_with_index do |command_ran, index|
      # seek to starting point of first command to match
      next unless index >= command_start_index
      if remaining_commands.size > 0
        expect(remaining_commands[0]).to eq(command_ran.command)
        remaining_commands.shift
      end
    end

    return remaining_commands.count == 0
  end

  supports_block_expectations

  failure_message do |block|
    "expected to have run these commands in order:\n\t\t#{commands.inspect}\n\tgot:\n\t\t#{$commands_ran.map(&:command).inspect}"
  end
end

RSpec::Matchers.define :have_said do |expected_message, expected_type|
  match do |block|
    block.call
    $says.include?({message: expected_message, type: expected_type})
  end

  supports_block_expectations

  failure_message do |block|
    "expected GitReflow to have said #{expected_message} with #{expected_type.inspect} but didn't: \n\t#{$says.inspect}"
  end
end

RSpec::Matchers.define :have_output do |expected_output|
  match do |block|
    block.call
    $output.join("\n").include? expected_output
  end

  supports_block_expectations

  failure_message do |block|
    "expected STDOUT to include #{expected_output} but didn't: \n\t#{$output.inspect}"
  end
end
