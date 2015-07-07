desc 'Setup your GitHub account'
command :setup do |c|
  c.desc 'sets up your api token with GitHub'
  c.switch [:l, :local], default_value: false, desc: 'setup GitReflow for the current project only'
  c.switch [:e, :enterprise], default_value: false, desc: 'setup GitReflow with a Github Enterprise account'
  c.switch [:trello, :"use-trello"], default_value: false, desc: 'setup GitReflow for use with a Trello account'
  c.action do |global_options, options, args|
    reflow_options = { project_only: options[:local], enterprise: options[:enterprise] }
    reflow_already_setup = (
      !GitReflow::Config.get('reflow.git-server').empty? and
      !GitReflow::Config.get('github.user').empty? and
      !GitReflow::Config.get('github.site').empty? and
      !GitReflow::Config.get('github.endpoint').empty? and
      !GitReflow::Config.get('github.oauth-token').empty?
    )

    unless reflow_already_setup
      choose do |menu|
        menu.header = "Available remote Git Server services:"
        menu.prompt = "Which service would you like to use for this project?  "

        menu.choice('GitHub')    { GitReflow::GitServer.connect reflow_options.merge({ provider: 'GitHub', silent: false }) }
        menu.choice('BitBucket (team-owned repos only)') { GitReflow::GitServer.connect reflow_options.merge({ provider: 'BitBucket', silent: false }) }
      end
    end

    if options[:"use-trello"] or options[:trello]
      if GitReflow::Config.get('trello.api-key').length <= 0
        GitReflow.say "Visit: https://trello.com/app-key"
        trello_key = ask("Enter your Developer API Key found on the URL above: ")
        GitReflow.say "Visit: https://trello.com/1/authorize?key=#{trello_key}&response_type=token&expiration=never&scope=read,write&name=GitReflow"
        trello_member_key = ask("Enter your Member Token generated from the URL above: ")
      end

      GitReflow.setup_trello

      # Ensure defaults are setup
      GitReflow::Config.set('trello.next-list-id', 'Next', local: true)
      GitReflow::Config.set('trello.current-list-id', 'In Progress', local: true)
      GitReflow::Config.set('trello.staged-list-id', 'Staged', local: true)
      GitReflow::Config.set('trello.approved-list-id', 'Approved', local: true)
      GitReflow::Config.set('trello.completed-list-id', 'Live', local: true)

      board_for_this_project = ask("Enter the name of the Trello board for this project: ")
      GitReflow::Config.set('trello.board-id', board_for_this_project.downcase, local: true)
    end
  end
end
