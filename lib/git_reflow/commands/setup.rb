desc 'Setup your GitHub account'
command :setup do |c|
  c.desc 'sets up your api token with GitHub'
  c.action do |global_options, options, args|
    GitReflow.setup
  end
end
