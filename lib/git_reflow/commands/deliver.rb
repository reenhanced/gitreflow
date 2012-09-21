desc 'deliver your feature branch'
long_desc 'merge your feature branch down to your base branch, and cleanup your feature branch'

command :deliver do |c|
  c.desc 'merge your feature branch down to your base branch, and cleanup your feature branch'
  c.arg_name 'base_branch - the branch you want to merge into'
  c.action do |global_options,options,args|
    deliver_options = {'base' => nil, 'head' => nil}
    case args.length
    when 2
      deliver_options['base'] = args[0]
      deliver_options['head'] = args[1]
    when 1
      deliver_options['base'] = args[0]
    end
    GitReflow.deliver deliver_options
  end
end
