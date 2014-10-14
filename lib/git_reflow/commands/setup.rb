desc 'Setup your GitHub account'
command :setup do |c|
  c.desc 'sets up your api token with GitHub'
  c.switch [:l, :local], default_value: false, desc: 'setup GitReflow for the current project only'
  c.switch [:e, :enterprise], default_value: false, desc: 'setup GitReflow with a Github Enterprise account'
  c.action do |global_options, options, args|
    reflow_options = { project_only: options[:local], enterprise: options[:enterprise] }
    choose do |menu|
      menu.header = "Available remote Git Server services:"
      menu.prompt = "Which service would you like to use for this project?  "

      menu.choice('GitHub')    { GitReflow::GitServer.connect reflow_options.merge({ provider: 'GitHub' }) }
      menu.choice('BitBucket') { say("Comming soon...") }
    end
  end
end
