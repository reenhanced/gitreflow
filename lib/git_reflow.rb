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
require 'git_reflow/git_server/bit_bucket'
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

      if existing_pull_request = git_server.find_pull_request( from: current_branch, to: options['base'] )
        puts "A pull request already exists for these branches:"
        display_pull_request_summary(existing_pull_request)
        ask_to_open_in_browser(existing_pull_request.html_url)
      else
        pull_request = git_server.create_pull_request(title: options['title'],
                                                      body:  options['body'],
                                                      head:  "#{remote_user}:#{current_branch}",
                                                      base:  options['base'])

        puts "Successfully created pull request ##{pull_request.number}: #{pull_request.title}\nPull Request URL: #{pull_request.html_url}\n"
        ask_to_open_in_browser(pull_request.html_url)
      end
    rescue Github::Error::UnprocessableEntity => e
      puts "Github Error: #{e.to_s}"
    rescue StandardError => e
      puts "Error: #{e.inspect}"
    end
  end

  def deliver(options = {})
    feature_branch    = current_branch
    options['base'] ||= 'master'
    fetch_destination options['base']

    update_destination(current_branch)

    begin
      existing_pull_request = git_server.find_pull_request( :from => current_branch, :to => options['base'] )

      if existing_pull_request.nil?
        puts "Error: No pull request exists for #{remote_user}:#{current_branch}\nPlease submit your branch for review first with \`git reflow review\`"
      else

        open_comment_authors = git_server.find_authors_of_open_pull_request_comments(existing_pull_request)
        has_comments         = git_server.has_pull_request_comments?(existing_pull_request)
        status = git_server.get_build_status existing_pull_request.head.sha

        # if there any comment_authors left, then they haven't given a lgtm after the last commit
        if ((status.nil? or status.state == "success") and has_comments and open_comment_authors.empty?) or options['skip_lgtm']
          lgtm_authors   = git_server.comment_authors_for_pull_request(existing_pull_request, :with => LGTM)
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
    @git_server ||= GitServer.connect provider: 'GitHub', silent: true
  end

  def display_pull_request_summary(pull_request)
    summary_data = {
      "branches"    => "#{pull_request.head.label} -> #{pull_request.base.label}",
      "number"      => pull_request.number,
      "url"         => pull_request.html_url
    }

    notices = ""
    reviewed_by = git_server.comment_authors_for_pull_request(pull_request).map {|author| author.colorize(:red) }

    # check for CI build status
    status = git_server.get_build_status pull_request.head.sha
    if status
      notices << "[notice] Your build status is not successful: #{status.target_url}.\n" unless status.state == "success"
      summary_data.merge!( "Build status" => git_server.colorized_build_description(status) )
    end

    # check for needed lgtm's
    pull_comments = git_server.pull_request_comments(pull_request)
    if pull_comments.reject {|comment| comment.user.login == git_server.class.user}.any?
      open_comment_authors = git_server.find_authors_of_open_pull_request_comments(pull_request)
      last_committed_at    = git_server.get_commited_time(pull_request.head.sha)
      lgtm_authors         = git_server.comment_authors_for_pull_request(pull_request, :with => LGTM, :after => last_committed_at)

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
end
