module CommandLineHelpers
  def stub_command_line
    $commands_ran = []
    $output       = []

    GitReflow::Sandbox.stub(:run) do |command, options|
      options ||= {}
      $commands_ran << Hashie::Mash.new(command: command, options: options)
      command = "" # we need this due to a bug in rspec that will keep this assignment on subsequent runs of the stub
    end

    STDOUT.stub(:puts) do |output|
      $output << output
      output = ''
    end
  end

  def reset_stubbed_command_line
    $commands_ran = []
  end

  def stub_command(command, return_value)
    GitReflow::Sandbox.stub(:run).with(command).and_return(return_value)
  end

  def has_ran_command?(command)
    $commands_ran.should include command
  end

  def has_ran_commands_in_order?(commands)
    command_count = commands.count
    $commands_ran.reverse.each_with_index do |command_ran, index|
      if command_count >= 1
        current_command = commands[command_count - 1]
        current_command[:command].should == command_ran.command
        current_command[:options].should == command_ran.options if current_command.has_key?(:options)
        command_count -= 1
      end
    end
    return true
  end
  alias :ran_commands_in_order? :has_ran_commands_in_order?
end
