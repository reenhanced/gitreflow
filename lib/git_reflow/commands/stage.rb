desc 'Deliver your changes to a staging server'
command :stage do |c|
  c.desc 'deliver your feature branch to the staging branch'
  c.action do |global_options, options, args|
    feature_branch_name = GitReflow.current_branch
    staging_branch_name = GitReflow::Config.get('reflow.staging-branch', local: true)

    begin
      current_card = GitReflow.current_trello_card
    rescue Trello::Error
      current_card = nil
    end

    if staging_branch_name.empty?
      staging_branch_name = GitReflow.ask("What's the name of your staging branch? (default: 'staging') ")
      staging_branch_name = 'staging' if staging_branch_name.strip == ''
      GitReflow::Config.set('reflow.staging-branch', staging_branch_name, local: true)
    end

    GitReflow.run_command_with_label "git checkout #{staging_branch_name}"
    GitReflow.run_command_with_label "git pull origin #{staging_branch_name}"

    if GitReflow.run_command_with_label "git merge #{feature_branch_name}", with_system: true
      GitReflow.run_command_with_label "git push origin #{staging_branch_name}"

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
