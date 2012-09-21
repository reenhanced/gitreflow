desc 'Display information about the status of your feature in the review process'
arg_name "destination_branch - the branch you're merging your feature into ('master' is default)"
command :status do |c|
  c.action do |global_options, options, args|
    destination_branch = args[0] || 'master'
    GitReflow.status destination_branch
  end
end
