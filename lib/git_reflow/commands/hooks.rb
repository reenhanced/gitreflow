desc 'Add a service hook to any git-reflow command'
arg_name '[new-feature-branch-name] - name of the new feature branch'
command :hooks do |c|
  c.desc 'List all service hooks for this project'
  c.command :list do |list|
    list.action do
      configured_hooks = `git config --global --get-regexp 'reflow(.+)*hooks.*'`
      configured_hooks.split('\n').each do |hook|
        puts "[hook] #{hook.gsub(/reflow\.hooks\./, '').slice(/.*\./)[0..-2]}"
      end
    end
  end

  c.desc 'Add a new service hook to a git-reflow command'
  c.command :add do |add|
    add.action do |global_options, options, args|
      # git config --replace-all reflow.hooks.service 'campfire'
      # TODO
      #       1) Ask for service type
      #       2) check for existing setup
      #         i) if not setup ask for Service.required_credentials
      #       3) ask for command to add hook to
      #       4) ask for before or after command
      case args.length
      when 2
        # check for valid service
        # split command:before|after and check for valid command and pre/post-fix
      when 1
        # check for valid service
        # then 2-4
      else
        # 1-4
      end
      # 1) Ask for service type
      puts "\nSelect a service you want this hook to use:"
      GitReflow::Services::supported_services.each_with_index do |service, index|
        puts "\t#{index+1}) #{service.name}"
      end
      selection = ask "\nEnter the number for the corresponding service: "

      # 2) Check for existing setup
      selection = selection.to_i - 1
      selected_service = GitReflow::Services::supported_services[selection]
      exit_now! 'Please enter a valid number for the service you want to use' unless selected_service

      unless selected_service.setup?
        puts "\nYou must setup your Campfire account..."
        selected_service.setup
      else
        puts "Campfire already setup...\n"
      end

      # 3) ask for command to add hook to
      puts "\nSelect a command you want this to hook onto:"
      GitReflow::commands.each_with_index do |command, index|
        puts "\t#{index+1}) #{command}"
      end

      selection = ask "\nEnter the number for the corresponding command: "
      selection = selection.to_i - 1
      selected_command = GitReflow.commands[selection]
      exit_now! 'Please enter a valid number for the service you want to use' unless selected_command

      # 4) ask for before or after command
      selection = ask "\nPerform this hook before or after this command? "

      case selection
      when /^b/
        selected_service.add_hook(:command => selected_command, :timing => 'before')
      else
        selected_service.add_hook(:command => selected_command, :timing => 'after')
      end

    end
  end

  c.desc 'Remove an existing service hook for a git-reflow command'
  c.command :remove do |remove|
    remove.action do |global_options, options, args|

    end
  end

  c.default_command :list
end
