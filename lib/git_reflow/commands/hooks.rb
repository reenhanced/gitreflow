desc 'Add a service hook to any git-reflow command'
arg_name '[new-feature-branch-name] - name of the new feature branch'
command :hooks do |c|
  c.desc 'List all service hooks for this project'
  c.command :list do |list|
    list.action do
      configured_hooks = `git --global config --get-regexp 'reflow(.+)*hooks.*'`
    end
  end

  c.desc 'Add a new service hook to a git-reflow command'
  c.command :add do |add|
    add.action do |global_options, options, args|
      # git config --replace-all reflow.hooks.service 'campfire'
      if args.empty?
        raise "usage: git-reflow start [new-branch-name]"
      else
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
