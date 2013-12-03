desc 'Setup your GitHub account'
command :setup do |c|
  c.desc 'sets up your api token with GitHub'
  c.switch [:l, :local], default_value: false, desc: 'setup GitReflow for the current project only'
  c.switch [:e, :enterprise], default_value: false, desc: 'setup GitReflow with a Github Enterprise account'
  c.flag [:"github-oauth-token-file"], default_value: File.join(ENV['HOME'], '.github-oauth-token'), desc: 'the file in which the Github OAuth token will be stored'

  c.action do |global_options, options, args|
    GitReflow.setup({ project_only: options[:local], enterprise: options[:enterprise], github_oauth_token_file: options[:"github-oauth-token-file"] })
  end
end
