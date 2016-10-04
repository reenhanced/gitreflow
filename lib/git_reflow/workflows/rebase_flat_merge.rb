class RebaseFlatMerge < GitReflow::Workflows::Core
  def self.deliver(**params)
    base_branch = params[:base] || 'master'

    if GitReflow.current_branch_commit_count(base: base_branch) > 1
      GitReflow.say "Rebasing to cleanup your commit history for this branch.", :notice
      GitReflow.say "Once you have completed your rebase, re-run git-reflow deliver.", :notice
      GitReflow.fetch_destination(base_branch)
      GitReflow.run "git rebase -i origin/#{base_branch}"
    else
      super(**params)
    end
  end
end

RebaseFlatMerge
