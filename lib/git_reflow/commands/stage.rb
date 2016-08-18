desc 'Deliver your changes to a staging server'
command :stage do |c|
  c.desc 'deliver your feature branch to the staging branch'
  c.action do |global_options, options, args|

    GitReflow.stage

  end
end
