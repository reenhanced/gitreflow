
desc 'Start will create a new feature branch and setup remote tracking'
long_desc <<LONGTIME
  Performs the following:\n
  \t$ git checkout <base_branch>\n
  \t$ git pull origin <base_branch>\n
  \t$ git push origin <base_branch>:refs/heads/[new_feature_branch]\n
  \t$ git checkout --track -b [new_feature_branch] origin/[new_feature_branch]\n
LONGTIME
arg_name '[new-feature-branch-name] - name of the new feature branch'
command :start do |c|
  c.flag [:b,:base], default_value: 'master'
  c.action do |global_options, options, args|
    if args.empty?
      raise "usage: git-reflow start [new-branch-name]"
    else
      # base_branch is the branch that you want to base your feature branch off of
      # This command allows you to 'git reflow start' off your base branch
      base_branch = options[:base]
  
      `git checkout #{base_branch}`
      `git pull origin #{base_branch}`
      `git push origin #{GitReflow.current_branch}:refs/heads/#{args[0]}`
      `git checkout --track -b #{args[0]} origin/#{args[0]}`
    end
  end
end
