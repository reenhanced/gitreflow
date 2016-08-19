desc 'Setup your GitHub account'
command :setup do |c|
  c.desc 'sets up your api token with GitHub'
  c.switch [:l, :local], default_value: false, desc: 'setup GitReflow for the current project only'
  c.switch [:e, :enterprise], default_value: false, desc: 'setup GitReflow with a Github Enterprise account'
  c.action do |global_options, options, args|

    GitReflow.setup local: options[:local], enterprise: options[:enterprise]

  end
end
