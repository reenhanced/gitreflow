require 'git_reflow/config'
require 'git_reflow/sandbox'

module GitReflow
  module GitHelpers
    include Sandbox

    def git_root_dir
      @git_root_dir ||= run('git rev-parse --show-toplevel', loud: false).strip
    end

    def git_editor_command
      GitReflow::Config.get('core.editor') || GitReflow.default_editor
    end

    def remote_user
      return "" unless "#{GitReflow::Config.get('remote.origin.url')}".length > 0
      extract_remote_user_and_repo_from_remote_url(GitReflow::Config.get('remote.origin.url'))[:user]
    end

    def remote_repo_name
      return "" unless "#{GitReflow::Config.get('remote.origin.url')}".length > 0
      extract_remote_user_and_repo_from_remote_url(GitReflow::Config.get('remote.origin.url'))[:repo]
    end

    def current_branch
      run("git branch --no-color | grep '^\* ' | grep -v 'no branch' | sed 's/^* //g'", loud: false).strip
    end

    def pull_request_template
      filenames_to_try = %w( github/PULL_REQUEST_TEMPLATE.md
                             github/PULL_REQUEST_TEMPLATE
                             PULL_REQUEST_TEMPLATE.md
                             PULL_REQUEST_TEMPLATE ).map do |file|
        "#{git_root_dir}/#{file}"
      end

      filename = filenames_to_try.detect do |file|
        File.exist? file
      end

      File.read filename if filename
    end

    def get_first_commit_message
      run('git log --pretty=format:"%s" --no-merges -n 1', loud: false).strip
    end

    def push_current_branch(options = {})
      remote = options[:remote] || "origin"
      run_command_with_label "git push #{remote} #{current_branch}"
    end

    def update_current_branch(options = {})
      remote = options[:remote] || "origin"
      run_command_with_label "git pull #{remote} #{current_branch}"
      push_current_branch(options)
    end

    def fetch_destination(destination_branch)
      run_command_with_label "git fetch origin #{destination_branch}"
    end

    def update_destination(destination_branch, options = {})
      origin_branch = current_branch
      remote = options[:remote] || 'origin'
      run_command_with_label "git checkout #{destination_branch}"
      run_command_with_label "git pull #{remote} #{destination_branch}"
      run_command_with_label "git checkout #{origin_branch}"
    end

    def update_feature_branch(options = {})
      base_branch = options[:base]
      remote = options[:remote]
      update_destination(base_branch, options) 

      # update feature branch in case there are multiple authors and remote changes
      run_command_with_label "git pull origin #{current_branch}"
      # rebase on base branch
      run_command_with_label "git merge #{base_branch}"
    end

    def append_to_squashed_commit_message(message = '')
      tmp_squash_message_path = "#{git_root_dir}/.git/tmp_squash_msg"
      squash_message_path     = "#{git_root_dir}/.git/SQUASH_MSG"
      File.open(tmp_squash_message_path, "w") do |file_content|
        file_content.puts message
        if File.exists?(squash_message_path)
          File.foreach(squash_message_path) do |line|
            file_content.puts line
          end
        end
      end

      run "mv #{tmp_squash_message_path} #{squash_message_path}"
    end

    private

    def extract_remote_user_and_repo_from_remote_url(remote_url)
      result = { user: '', repo: '' }
      return result unless "#{remote_url}".length > 0

      if remote_url =~ /\Agit@/i
        result[:user] = remote_url[/[\/:](\w|-|\.)+/i][1..-1]
        result[:repo] = remote_url[/\/(\w|-|\.)+$/i][1..-5]
      elsif remote_url =~ /\Ahttps?/i
        result[:user] = remote_url.split('/')[-2]
        result[:repo] = remote_url.split('/')[-1].gsub(/.git\Z/i, '')
      end

      result
    end
  end
end
