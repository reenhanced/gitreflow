require 'git_reflow/config'
require 'git_reflow/sandbox'

module GitReflow
  module GitHelpers
    include Sandbox

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

    def merge_feature_branch(feature_branch_name, options = {})
      options[:destination_branch] ||= 'master'

      message = "#{options[:message]}"

      if "#{options[:pull_request_number]}".length > 0
        message << "\nCloses ##{options[:pull_request_number]}\n"
      end

      if lgtm_authors = Array(options[:lgtm_authors]) and lgtm_authors.any?
        message << "\nLGTM given by: @#{lgtm_authors.join(', @')}\n"
      end

      run_command_with_label "git checkout #{options[:destination_branch]}"
      run_command_with_label "git merge --squash #{feature_branch_name}"

      append_to_squashed_commit_message(message) if message.length > 0
    end

    def append_to_squashed_commit_message(message = '')
      run "echo \"#{message}\" | cat - .git/SQUASH_MSG > ./tmp_squash_msg"
      run 'mv ./tmp_squash_msg .git/SQUASH_MSG'
    end
  end
end
