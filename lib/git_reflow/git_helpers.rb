require 'git_reflow/config'

module GitReflow
  module GitHelpers
    def remote_user
      return "" unless "#{GitReflow::Config.get('remote.origin.url')}".length > 0
      GitReflow::Config.get('remote.origin.url')[/[\/:](\w|-|\.)+/i][1..-1]
    end

    def remote_repo_name
      return "" unless "#{GitReflow::Config.get('remote.origin.url')}".length > 0
      GitReflow::Config.get('remote.origin.url')[/\/(\w|-|\.)+$/i][1..-5]
    end

    def current_branch
      run("git branch --no-color | grep '^\* ' | grep -v 'no branch' | sed 's/^* //g'", loud: false).strip
    end

    def get_first_commit_message
      run('git log --pretty=format:"%s" --no-merges -n 1', loud: false).strip
    end

    def push_current_branch
      run_command_with_label "git push origin #{current_branch}"
    end

    def fetch_destination(destination_branch)
      run_command_with_label "git fetch origin #{destination_branch}"
    end

    def update_destination(destination_branch)
      origin_branch = current_branch
      run_command_with_label "git checkout #{destination_branch}"
      run_command_with_label "git pull origin #{destination_branch}"
      run_command_with_label "git checkout #{origin_branch}"
    end

    def merge_feature_branch(options = {})
      options[:destination_branch] ||= 'master'
      message                        = options[:message] || "\nCloses ##{options[:pull_request_number]}\n"

      run_command_with_label "git checkout #{options[:destination_branch]}"
      run_command_with_label "git merge --squash #{options[:feature_branch]}"
      # append pull request number to commit message
      append_to_squashed_commit_message(message)
    end

    def append_to_squashed_commit_message(message = '')
      run "echo "#{message}" | cat - .git/SQUASH_MSG > ./tmp_squash_msg"
      run 'mv ./tmp_squash_msg .git/SQUASH_MSG'
    end
  end
end
