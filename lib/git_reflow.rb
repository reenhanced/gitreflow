require 'rubygems'
require 'open-uri'
require "highline/import"
require 'httpclient'
require 'github_api'
require 'json/pure'
require 'colorize'

require 'git_reflow/version.rb' unless defined?(GitReflow::VERSION)
require 'git_reflow/config'
require 'git_reflow/git_server'
require 'git_reflow/git_server/git_hub'
require 'git_reflow/sandbox'
require 'git_reflow/git_helpers'

module GitReflow
  include Sandbox
  include GitHelpers

  extend self

  LGTM = /lgtm|looks good to me|:\+1:|:thumbsup:|:shipit:/i

  def status(destination_branch)
    pull_request = git_server.find_pull_request( :from => current_branch, :to => destination_branch )

    if pull_request.nil?
      puts "\n[notice] No pull request exists for #{current_branch} -> #{destination_branch}"
      puts "[notice] Run 'git reflow review #{destination_branch}' to start the review process"
    else
      puts "Here's the status of your review:"
      display_pull_request_summary(pull_request)
      ask_to_open_in_browser(pull_request.html_url)
    end
  end

  def review(options = {})
    options['base'] ||= 'master'
    fetch_destination options['base']

    begin
      push_current_branch

      if existing_pull_request = find_pull_request( :from => current_branch, :to => options['base'] )
        puts "A pull request already exists for these branches:"
        display_pull_request_summary(existing_pull_request)
        ask_to_open_in_browser(existing_pull_request.html_url)
      else
        pull_request = github.pull_requests.create(remote_user, remote_repo_name,
                                                   'title' => options['title'],
                                                   'body'  => options['body'],
                                                   'head'  => "#{remote_user}:#{current_branch}",
                                                   'base'  => options['base'])

        puts "Successfully created pull request ##{pull_request.number}: #{pull_request.title}\nPull Request URL: #{pull_request.html_url}\n"
        ask_to_open_in_browser(pull_request.html_url)
      end
    rescue Github::Error::UnprocessableEntity => e
      puts "Github Error: #{e.to_s}"
    end
  end

  def deliver(options = {})
    feature_branch    = current_branch
    options['base'] ||= 'master'
    fetch_destination options['base']

    update_destination(current_branch)

    begin
      existing_pull_request = find_pull_request( :from => current_branch, :to => options['base'] )

      if existing_pull_request.nil?
        puts "Error: No pull request exists for #{remote_user}:#{current_branch}\nPlease submit your branch for review first with \`git reflow review\`"
      else

        open_comment_authors = find_authors_of_open_pull_request_comments(existing_pull_request)
        has_comments         = has_pull_request_comments?(existing_pull_request)
        status = get_build_status existing_pull_request.head.sha

        # if there any comment_authors left, then they haven't given a lgtm after the last commit
        if ((status.nil? or status.state == "success") and has_comments and open_comment_authors.empty?) or options['skip_lgtm']
          lgtm_authors   = comment_authors_for_pull_request(existing_pull_request, :with => LGTM)
          commit_message = ("#{existing_pull_request[:body]}".length > 0) ? existing_pull_request[:body] : "#{get_first_commit_message}"
          puts "Merging pull request ##{existing_pull_request.number}: '#{existing_pull_request.title}', from '#{existing_pull_request.head.label}' into '#{existing_pull_request.base.label}'"

          update_destination(options['base'])
          merge_feature_branch(feature_branch,
                               :destination_branch  => options['base'],
                               :pull_request_number => existing_pull_request.number,
                               :lgtm_authors        => lgtm_authors,
                               :message             => commit_message)
          committed = run_command_with_label 'git commit', with_system: true

          if committed
            puts "Merge complete!"
            deploy_and_cleanup = ask "Would you like to push this branch to your remote repo and cleanup your feature branch? "
            if deploy_and_cleanup =~ /^y/i
              run_command_with_label "git push origin #{options['base']}"
              run_command_with_label "git push origin :#{feature_branch}"
              run_command_with_label "git branch -D #{feature_branch}"
              puts "Nice job buddy."
            else
              puts "Cleanup haulted.  Local changes were not pushed to remote repo.".colorize(:red)
              puts "To reset and go back to your branch run \`git reset --hard origin/master && git checkout new-feature\`"
            end
          else
            puts "There were problems commiting your feature... please check the errors above and try again."
          end
        elsif !status.nil? and status.state != "success"
          puts "[#{ 'deliver halted'.colorize(:red) }] #{status.description}: #{status.target_url}"
        elsif open_comment_authors.count > 0
          puts "[deliver halted] You still need a LGTM from: #{open_comment_authors.join(', ')}"
        else
          puts "[deliver halted] Your code has not been reviewed yet."
        end
      end

    rescue Github::Error::UnprocessableEntity => e
      errors = JSON.parse(e.response_message[:body])
      error_messages = errors["errors"].collect {|error| "GitHub Error: #{error["message"].gsub(/^base\s/, '')}" unless error["message"].nil?}.compact.join("\n")
      puts "Github Error: #{error_messages}"
    end
  end

  def git_server
    @git_server ||= GitServer.connect provider: 'GitHub'
  end

  def pull_request_comments(pull_request)
    comments        = github.issues.comments.all        remote_user, remote_repo_name, issue_id:   pull_request.number
    review_comments = github.pull_requests.comments.all remote_user, remote_repo_name, request_id: pull_request.number

    review_comments.to_a + comments.to_a
  end

  def has_pull_request_comments?(pull_request)
    pull_request_comments(pull_request).count > 0
  end

  def get_build_status sha
    github.repos.statuses.all(remote_user, remote_repo_name, sha).first
  end

  def build_color status
    colorized_statuses = { pending: :yellow, success: :green, error: :red, failure: :red }
    colorized_statuses[status.state.to_sym]
  end

  def colorized_build_description status
    status.description.colorize( build_color status )
  end

  def find_authors_of_open_pull_request_comments(pull_request)
    # first we'll gather all the authors that have commented on the pull request
    pull_last_committed_at = get_commited_time(pull_request.head.sha)
    comment_authors        = comment_authors_for_pull_request(pull_request)
    lgtm_authors           = comment_authors_for_pull_request(pull_request, :with => LGTM, :after => pull_last_committed_at)

    comment_authors - lgtm_authors
  end

  def comment_authors_for_pull_request(pull_request, options = {})
    all_comments    = pull_request_comments(pull_request)
    comment_authors = []

    all_comments.each do |comment|
      next if options[:after] and Time.parse(comment.created_at) < options[:after]
      if (options[:with].nil? or comment[:body] =~ options[:with])
        comment_authors |= [comment.user.login]
      end
    end

    # remove the current user from the list to check
    comment_authors -= [github_user]
  end

  def display_pull_request_summary(pull_request)
    summary_data = {
      "branches"    => "#{pull_request.head.label} -> #{pull_request.base.label}",
      "number"      => pull_request.number,
      "url"         => pull_request.html_url
    }

    notices = ""
    reviewed_by = comment_authors_for_pull_request(pull_request).map {|author| author.colorize(:red) }

    # check for CI build status
    status = get_build_status pull_request.head.sha
    if status
      notices << "[notice] Your build status is not successful: #{status.target_url}.\n" unless status.state == "success"
      summary_data.merge!( "Build status" => colorized_build_description(status) )
    end

    # check for needed lgtm's
    pull_comments = pull_request_comments(pull_request)
    if pull_comments.reject {|comment| comment.user.login == github_user}.any?
      open_comment_authors = find_authors_of_open_pull_request_comments(pull_request)
      last_committed_at    = get_commited_time(pull_request.head.sha)
      lgtm_authors         = comment_authors_for_pull_request(pull_request, :with => LGTM, :after => last_committed_at)

      summary_data.merge!("Last comment"  => pull_comments.last[:body].inspect)

      if lgtm_authors.any?
        reviewed_by.map! { |author| lgtm_authors.include?(author.uncolorize) ? author.colorize(:green) : author }
      end

      notices << "[notice] You still need a LGTM from: #{open_comment_authors.join(', ')}\n" if open_comment_authors.any?
    else
      notices << "[notice] No one has reviewed your pull request.\n"
    end

    summary_data['reviewed by'] = reviewed_by.join(', ')

    padding_size = summary_data.keys.max_by(&:size).size + 2
    summary_data.keys.sort.each do |name|
      string_format = "    %-#{padding_size}s %s\n"
      printf string_format, "#{name}:", summary_data[name]
    end

    puts "\n#{notices}" unless notices.empty?
  end

  def get_commited_time(commit_sha)
    last_commit = github.repos.commits.find remote_user, remote_repo_name, commit_sha
    Time.parse last_commit.commit.author[:date]
  end
end
