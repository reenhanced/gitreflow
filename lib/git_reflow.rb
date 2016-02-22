require 'rubygems'
require 'open-uri'
require "highline/import"
require 'httpclient'
require 'github_api'
require 'json'
require 'colorize'

require 'git_reflow/version.rb' unless defined?(GitReflow::VERSION)
require 'git_reflow/config'
require 'git_reflow/git_server'
require 'git_reflow/git_server/git_hub'
require 'git_reflow/git_server/bit_bucket'
require 'git_reflow/os_detector'
require 'git_reflow/sandbox'
require 'git_reflow/git_helpers'

module GitReflow
  include Sandbox
  include GitHelpers

  extend self

  LGTM = /lgtm|looks good to me|:\+1:|:thumbsup:|:shipit:/i

  def status(destination_branch)
    pull_request = git_server.find_open_pull_request( :from => current_branch, :to => destination_branch )

    if pull_request.nil?
      puts "\n[notice] No pull request exists for #{current_branch} -> #{destination_branch}"
      puts "[notice] Run 'git reflow review #{destination_branch}' to start the review process"
    else
      puts "Here's the status of your review:"
      pull_request.display_pull_request_summary
      ask_to_open_in_browser(pull_request.html_url)
    end
  end

  def review(options = {})
    options['base']     ||= 'master'
    create_pull_request   = true

    fetch_destination options['base']

    begin
      push_current_branch

      existing_pull_request = git_server.find_open_pull_request( from: current_branch, to: options['base'] )
      if existing_pull_request
        say "A pull request already exists for these branches:", :notice
        existing_pull_request.display_pull_request_summary
        ask_to_open_in_browser(existing_pull_request.html_url)
      else
        unless options['title'] || options['body']
          pull_request_msg_file = "#{GitReflow.git_root_dir}/.git/GIT_REFLOW_PR_MSG"
          default_editor        = "#{ENV['EDITOR']}"

          if default_editor.empty?
            default_editor = 'vi'
          end

          File.open(pull_request_msg_file, 'w') do |file|
            file.write(options['title'] || GitReflow.current_branch)
          end

          GitReflow.run("#{default_editor} #{pull_request_msg_file}", with_system: true)

          pr_msg = File.read(pull_request_msg_file).split(/[\r\n]|\r\n/).map(&:strip)
          title  = pr_msg.shift

          File.delete(pull_request_msg_file)

          unless pr_msg.empty? 
            pr_msg.shift if pr_msg.first.empty?
          end

          options['title'] = title
          options['body']  = "#{pr_msg.join("\n")}\n"

          puts "\nReview your PR:\n"
          puts "--------\n"
          puts "Title:\n#{options['title']}\n\n"
          puts "Body:\n#{options['body']}\n"
          puts "--------\n"

          create_pull_request = ask("Submit pull request? (Y)") =~ /y/i
        end

        if create_pull_request
          pull_request = git_server.create_pull_request(title: options['title'] || options['body'],
                                                        body:  options['body'],
                                                        head:  "#{remote_user}:#{current_branch}",
                                                        base:  options['base'])

          puts "Successfully created pull request ##{pull_request.number}: #{pull_request.title}\nPull Request URL: #{pull_request.html_url}\n"
          ask_to_open_in_browser(pull_request.html_url)
        else
          say "Review aborted.  No pull request has been created.", :review_halted
        end
      end
    rescue Github::Error::UnprocessableEntity => e
      puts "Github Error: #{e.to_s}"
    rescue StandardError => e
      puts "\nError: #{e.inspect}"
    end
  end

  def deliver(options = {})
    feature_branch    = current_branch
    base_branch       = options['base'] || 'master'

    fetch_destination(base_branch)
    update_destination(feature_branch)

    begin
      existing_pull_request = git_server.find_open_pull_request( :from => current_branch, :to => base_branch )

      if existing_pull_request.nil?
        say "No pull request exists for #{remote_user}:#{current_branch}\nPlease submit your branch for review first with \`git reflow review\`", :deliver_halted
      else

        commit_message = if "#{existing_pull_request.description}".length > 0
                           existing_pull_request.description
                         else
                           "#{get_first_commit_message}"
                         end

        if existing_pull_request.good_to_merge?(force: options['skip_lgtm'])
          puts "Merging pull request ##{existing_pull_request.number}: '#{existing_pull_request.title}', from '#{existing_pull_request.feature_branch_name}' into '#{existing_pull_request.base_branch_name}'"

          update_destination(base_branch)
          merge_feature_branch(feature_branch,
                               :destination_branch  => base_branch,
                               :pull_request_number => existing_pull_request.number,
                               :lgtm_authors        => existing_pull_request.approvals,
                               :message             => commit_message)
          committed = run_command_with_label 'git commit', with_system: true

          if committed
            say "Merge complete!", :success

            # check if user always wants to push and cleanup, otherwise ask
            always_deploy_and_cleanup = GitReflow::Config.get('reflow.always-deploy-and-cleanup') == "true"
            deploy_and_cleanup = always_deploy_and_cleanup || (ask "Would you like to push this branch to your remote repo and cleanup your feature branch? ") =~ /^y/i

            if deploy_and_cleanup
              run_command_with_label "git push origin #{base_branch}"
              run_command_with_label "git push origin :#{feature_branch}"
              run_command_with_label "git branch -D #{feature_branch}"
              puts "Nice job buddy."
            else
              puts "Cleanup halted.  Local changes were not pushed to remote repo.".colorize(:red)
              puts "To reset and go back to your branch run \`git reset --hard origin/#{base_branch} && git checkout #{feature_branch}\`"
            end
          else
            say "There were problems commiting your feature... please check the errors above and try again.", :error
          end
        elsif !existing_pull_request.build_status.nil? and existing_pull_request.build_status != "success"
          say "#{existing_pull_request.build.description}: #{existing_pull_request.build.url}", :deliver_halted
        elsif existing_pull_request.reviewers_pending_response.count > 0
          say "You still need a LGTM from: #{existing_pull_request.reviewers_pending_response.join(', ')}", :deliver_halted
        else
          say "Your code has not been reviewed yet.", :deliver_halted
        end
      end

    rescue Github::Error::UnprocessableEntity => e
      errors = JSON.parse(e.response_message[:body])
      error_messages = errors["errors"].collect {|error| "GitHub Error: #{error["message"].gsub(/^base\s/, '')}" unless error["message"].nil?}.compact.join("\n")
      puts "Github Error: #{error_messages}"
    end
  end

  def deploy(destination_server)
    deploy_command = GitReflow::Config.get("reflow.deploy-to-#{destination_server}-command", local: true)

    # first check is to allow for automated setup
    if deploy_command.empty?
      deploy_command = ask("Enter the command you use to deploy to #{destination_server} (leaving blank will skip deployment)")
    end

    # second check is to see if the user wants to skip
    if deploy_command.empty?
      say "Skipping deployment..."
      false
    else
      GitReflow::Config.set("reflow.deploy-to-#{destination_server}-command", deploy_command, local: true)
      run_command_with_label(deploy_command, with_system: true)
    end
  end

  def git_server
    @git_server ||= GitServer.connect provider: GitReflow::Config.get('reflow.git-server').strip, silent: true
  end

end
