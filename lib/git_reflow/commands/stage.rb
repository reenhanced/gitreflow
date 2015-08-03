desc 'Deliver your changes to staging'
arg_name ''
command :stage do |c|
  c.desc 'deliver your feature branch to staging branch'
  c.arg_name ''
  c.action do |global_options, options, args|
    feature_branch_name = GitReflow.current_branch
    begin
      current_card = GitReflow.current_trello_card
    rescue Trello::Error
      current_card = nil
    end

    GitReflow.run_command_with_label 'git checkout staging'
    GitReflow.run_command_with_label 'git pull origin staging'
    if GitReflow.run_command_with_label "git merge #{feature_branch_name}", with_system: true
      GitReflow.run_command_with_label 'git push origin staging'

      staged = GitReflow.deploy(:staging)

      if current_card and staged
        current_card.move_to_list(GitReflow.trello_staged_list)
        GitReflow.say "Moved current trello card to 'Staged' list", :notice
      elsif staged
        GitReflow.say "Deployed to Staging.", :success
      else
        GitReflow.say "There were issues deploying to staging.", :error
      end
    else
      GitReflow.say "There were issues merging your feature branch to staging.", :error
    end
  end
end
