module CommandLineHelpers
  def stub_command_line
    $commands_ran = []
    $output       = []

    stub_run_for GitReflow
    stub_run_for GitReflow::Sandbox

    STDOUT.stub(:puts) do |output|
      $output << output
      output = ''
    end
  end

  def stub_run_for(module_to_stub)
    module_to_stub.stub(:run) do |command, options|
      options ||= {}
      $commands_ran << Hashie::Mash.new(command: command, options: options)
      command = "" # we need this due to a bug in rspec that will keep this assignment on subsequent runs of the stub
    end
  end

  def reset_stubbed_command_line
    $commands_ran = []
  end

  def stub_command(command, return_value)
    GitReflow::Sandbox.stub(:run).with(command).and_return(return_value)
  end
end

RSpec::Matchers.define :have_run_command do |command|
  match do |block|
    block.call
    (
      $commands_ran.include? Hashie::Mash.new(command: command, options: {}) or
      $commands_ran.include? Hashie::Mash.new(command: command, options: {with_system: true})
    )
  end

  supports_block_expectations

  failure_message do |block|
    "expected to have run the command \`#{command}\` but instead ran:\n\t#{$commands_ran.inspect}"
  end
end

RSpec::Matchers.define :have_run_command_silently do |command|
  match do |block|
    block.call
    $commands_ran.include? Hashie::Mash.new(command: command, options: { loud: false })
  end

  supports_block_expectations

  failure_message do |block|
    "expected to have run the command \`#{command}\` silently but instead ran:\n\t#{$commands_ran.inspect}"
  end
end

RSpec::Matchers.define :have_run_commands_in_order do |commands|
  match do |block|
    block.call
    command_count = commands.count
    command_start_index = $commands_ran.reverse.find_index {|c| c.command == commands.first }
    return false unless command_start_index

    $commands_ran.reverse.each_with_index do |command_ran, index|
      next unless command_start_index
      if command_count >= 1
        current_command = commands[command_count - 1]
        current_command.should == command_ran.command
        command_count -= 1
      end
    end

    return command_count == 0
  end

  supports_block_expectations

  failure_message do |block|
    "expected to have run these commands in order:\n\t\t#{commands.inspect}\n\tgot:\n\t\t#{$commands_ran.inspect}"
  end
end

RSpec::Matchers.define :have_output do |expected_output|
  match do |block|
    block.call
    $output.include? expected_output
  end

  supports_block_expectations

  failure_message do |block|
    "expected STDOUT to include #{expected_output} but didn't: \n\t#{$output.inspect}"
  end
end

