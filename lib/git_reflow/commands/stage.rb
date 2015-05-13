desc 'Deliver your changes to staging'
arg_name ''
command :stage do |c|
  c.desc 'deliver your feature branch to staging branch'
  c.arg_name ''
  c.action do |global_options, options, args|
    feature_branch_name = GitReflow.current_branch
    GitReflow.run_command_with_label 'git checkout staging'
    GitReflow.run_command_with_label 'git pull origin staging'
    if GitReflow.run_command_with_label "git merge #{feature_branch_name}", with_system: true
      GitReflow.run_command_with_label 'git push origin staging'
      if GitReflow.using_trello?
          current_card = Trello::Card.find(GitReflow.current_trello_card_id)
          current_card.move_to_list(GitReflow.trello_stage_list)
          GitReflow.say "Moved current trello card to 'Staged' list", :success
      end
    else
      GitReflow.say "There were issues merging your feature branch to staging.", :error
    end
  end
end
