# frozen_string_literal: true

require 'git_reflow/config'
require 'git_reflow/sandbox'

module GitReflow
  # Includes many helper methods for common tasks within a git repository.
  module GitHelpers
    include Sandbox

    def default_editor
      ENV['EDITOR'] || 'vi'
    end

    def git_root_dir
      return @git_root_dir unless @git_root_dir.to_s.empty?
      @git_root_dir = run('git rev-parse --show-toplevel', loud: false).strip
    end

    def git_editor_command
      git_editor = GitReflow::Config.get('core.editor')
      if !git_editor.empty?
        git_editor
      else
        default_editor
      end
    end

    def remote_user
      return '' if GitReflow::Config.get('remote.origin.url').empty?
      extract_remote_user_and_repo_from_remote_url(GitReflow::Config.get('remote.origin.url'))[:user]
    end

    def remote_repo_name
      return '' if GitReflow::Config.get('remote.origin.url').empty?
      extract_remote_user_and_repo_from_remote_url(GitReflow::Config.get('remote.origin.url'))[:repo]
    end

    def current_branch
      run("git branch --no-color | grep '^\* ' | grep -v 'no branch' | sed 's/^* //g'", loud: false).strip
    end

    def pull_request_template
      filenames_to_try = %w[.github/PULL_REQUEST_TEMPLATE.md
                            .github/PULL_REQUEST_TEMPLATE
                            PULL_REQUEST_TEMPLATE.md
                            PULL_REQUEST_TEMPLATE].map do |file|
        "#{git_root_dir}/#{file}"
      end

      parse_first_matching_template_file(filenames_to_try)
    end

    def merge_commit_template
      filenames_to_try = %w[.github/MERGE_COMMIT_TEMPLATE.md
                            .github/MERGE_COMMIT_TEMPLATE
                            MERGE_COMMIT_TEMPLATE.md
                            MERGE_COMMIT_TEMPLATE].map do |file|
        "#{git_root_dir}/#{file}"
      end

      parse_first_matching_template_file(filenames_to_try)
    end

    def get_first_commit_message
      run('git log --pretty=format:"%s" --no-merges -n 1', loud: false).strip
    end

    def push_current_branch(options = {})
      remote = options[:remote] || 'origin'
      run_command_with_label "git push #{remote} #{current_branch}"
    end

    def update_current_branch(options = {})
      remote = options[:remote] || 'origin'
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

    def append_to_merge_commit_message(message = '', merge_method: "squash")
      tmp_merge_message_path  = "#{git_root_dir}/.git/tmp_merge_msg"
      dest_merge_message_path = merge_message_path(merge_method: merge_method)

      run "touch #{tmp_merge_message_path}"

      File.open(tmp_merge_message_path, "w") do |file_content|
        file_content.puts message
        if File.exists? dest_merge_message_path
          File.foreach(dest_merge_message_path) do |line|
            file_content.puts line
          end
        end
      end

      run "mv #{tmp_merge_message_path} #{dest_merge_message_path}"
    end

    def merge_message_path(merge_method: nil)
      merge_method = merge_method || GitReflow::Config.get("reflow.merge-method")
      merge_method = "squash" if "#{merge_method}".length < 1
      if merge_method =~ /squash/i
        "#{git_root_dir}/.git/SQUASH_MSG"
      else
        "#{git_root_dir}/.git/MERGE_MSG"
      end
    end

    private

    def parse_first_matching_template_file(template_file_names)
      filename = template_file_names.detect do |file|
        File.exist? file
      end

      # Thanks to @Shalmezad for contribuiting the template `gsub` snippet :-)
      # https://github.com/reenhanced/gitreflow/issues/51#issuecomment-253535093
      if filename
        template_content = File.read filename
        template_content.gsub!(/\{\{([a-zA-Z_]+[a-zA-Z0-9_]*)\}\}/) { GitReflow.public_send($1) }
        template_content
      end
    end

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
