desc 'Start will create a new feature branch and setup remote tracking'
long_desc <<LONGTIME
  Performs the following:\n
  \t$ git pull origin <current_branch>\n
  \t$ git push origin master:refs/heads/[new_feature_branch]\n
  \t$ git checkout --track -b [new_feature_branch] origin/[new_feature_branch]\n
LONGTIME
arg_name '[new-feature-branch-name] - name of the new feature branch'
command :start do |c|
  c.desc 'Describe a switch to list'
  c.switch :s

  c.desc 'Describe a flag to list'
  c.default_value 'default'
  c.flag :f
  c.action do |global_options, options, args|
    if args.empty?
      raise "usage: git-reflow start [new-branch-name]"
    else
      `git pull origin #{GitReflow.current_branch}`
      `git push origin #{GitReflow.current_branch}:refs/heads/#{args[0]}`
      `git checkout --track -b #{args[0]} origin/#{args[0]}`
    end
  end
end
