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
      selection = ask "Enter the number for the corresponding service: "

      # 2) Check for existing setup
      case selection
      when /1/
        unless GitReflow::Services::Campfire.setup?
          puts "\nYou must setup your Campfire account..."
          GitReflow::Services::Campfire.setup
        else
          puts "Campfire setup..."
        end
      else
        exit_now! 'Please enter a valid number for the service you want to use'
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
