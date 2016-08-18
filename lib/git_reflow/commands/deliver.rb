desc 'deliver your feature branch'
long_desc 'merge your feature branch down to your base branch, and cleanup your feature branch'

command :deliver do |c|
  c.desc 'merge your feature branch down to your base branch, and cleanup your feature branch'
  c.switch [:f, :'skip-lgtm'], desc: 'skip the lgtm checks and deliver your feature branch'
  c.action do |global_options, options, args|
    GitReflow.deliver base: args[0], force: options[:'skip-lgtm']
  end
end
