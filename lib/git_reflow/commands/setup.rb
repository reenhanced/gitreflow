desc 'Setup your GitHub account'
command :setup do |c|
  c.desc 'sets up your api token with GitHub'
  c.switch [:l, :local], default_value: false, desc: 'setup GitReflow for the current project only'
  c.switch [:e, :enterprise], default_value: false, desc: 'setup GitReflow with a Github Enterprise account'
  c.action do |global_options, options, args|
    reflow_options             = { project_only: options[:local], enterprise: options[:enterprise] }
    existing_git_include_paths = GitReflow::Config.get('include.path', all: true).split("\n")

    unless File.exist?(GitReflow::Config::CONFIG_FILE_PATH) or existing_git_include_paths.include?(GitReflow::Config::CONFIG_FILE_PATH)
      GitReflow.run "touch #{GitReflow::Config::CONFIG_FILE_PATH}"
      GitReflow.say "Created #{GitReflow::Config::CONFIG_FILE_PATH} for Reflow specific configurations", :notice
      GitReflow::Config.add "include.path", GitReflow::Config::CONFIG_FILE_PATH, global: true
      GitReflow.say "Added #{GitReflow::Config::CONFIG_FILE_PATH} to ~/.gitconfig include paths", :notice
    end

    choose do |menu|
      menu.header = "Available remote Git Server services:"
      menu.prompt = "Which service would you like to use for this project?  "

      menu.choice('GitHub')    { GitReflow::GitServer.connect reflow_options.merge({ provider: 'GitHub', silent: false }) }
      menu.choice('BitBucket (team-owned repos only)') { GitReflow::GitServer.connect reflow_options.merge({ provider: 'BitBucket', silent: false }) }
    end
  end
end
