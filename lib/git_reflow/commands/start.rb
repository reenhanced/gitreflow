desc 'Start will create a new feature branch and setup remote tracking'
long_desc <<LONGTIME
  Performs the following:\n
  \t$ git pull origin <current_branch>\n
  \t$ git push origin <current_branch>:refs/heads/[new_feature_branch]\n
  \t$ git checkout --track -b [new_feature_branch] origin/[new_feature_branch]\n
LONGTIME
arg_name '[new-feature-branch-name] - name of the new feature branch'
command :start do |c|
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
