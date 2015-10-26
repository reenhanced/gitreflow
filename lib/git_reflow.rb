require 'rubygems'
require 'open-uri'
require "highline/import"
require 'httpclient'
require 'github_api'
require 'json'
require 'colorize'
require 'trello'

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
    options['base'] ||= 'master'
    fetch_destination options['base']

    begin
      push_current_branch

      existing_pull_request = git_server.find_open_pull_request( from: current_branch, to: options['base'] )
      if existing_pull_request
        puts "A pull request already exists for these branches:"
        existing_pull_request.display_pull_request_summary
        ask_to_open_in_browser(existing_pull_request.html_url)
      else
        pull_request = git_server.create_pull_request(title: options['title'],
                                                      body:  options['body'],
                                                      head:  "#{remote_user}:#{current_branch}",
                                                      base:  options['base'])

        puts "Successfully created pull request ##{pull_request.number}: #{pull_request.title}\nPull Request URL: #{pull_request.html_url}\n"

        if current_trello_card
          current_trello_card.add_attachment(pull_request.html_url, "Pull Request ##{pull_request.number}")
          say "Added pull request link to the current Trello card", :notice
        end

        ask_to_open_in_browser(pull_request.html_url)
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
    trello_card       = current_trello_card

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

        # check to see if current Trello card is in the Approved list
        feature_trello_card = current_trello_card
        if using_trello? and trello_uses_list?('approved') and trello_approved_list and current_trello_card
          if current_trello_card.list_id == trello_approved_list.id
            trello_approved = true
          else
            trello_approved = false
          end
        else
          # setting to 'true' here allows us to skip checks if not using Trello
          # or Approval process isn't setup correctly
          trello_approved = true
        end

        if trello_approved and existing_pull_request.good_to_merge?(force: options['skip_lgtm'])
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
        elsif trello_approved == true
          say "Your code has not been reviewed yet.", :deliver_halted
        else
          say "Your feature has not been Approved yet.  The current trello card ##{current_trello_card.short_id} needs to be in the 'Approved' list.", :deliver_halted
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

  def setup_trello
    @trello_member_token ||= Trello.configure do |config|
      config.developer_public_key = GitReflow::Config.get('trello.api-key')
      config.member_token         = GitReflow::Config.get('trello.member-token')
    end

    begin
      @trello_member_id ||= Trello::Token.find(@trello_member_token).member_id
      GitReflow::Config.set('trello.member-id', @trello_member_id, local: true)
    rescue Trello::Error => e
    end

    @trello_member_token
  end

  def using_trello?
    trello_presence = (GitReflow::Config.get('trello.board-id').length > 0 and GitReflow::Config.get('trello.next-list-id').length > 0)
    setup_trello if trello_presence
    trello_presence
  end

  def current_trello_member
    begin
      @trello_member ||= Trello::Member.find GitReflow::Config.get('trello.member-id')
    rescue Trello::Error => e
      nil
    end
  end

  def current_trello_card_id
    GitReflow::Config.get("branch.#{current_branch}.trello-card-id")
  end

  def current_trello_card
    return nil unless using_trello?
    begin
      Trello::Card.find(current_trello_card_id)
    rescue Trello::Error
      nil
    end
  end

  def trello_lists
    begin
      @trello_lists ||= Trello::Board.find(GitReflow::Config.get('trello.board-id', local: true)).lists
    rescue Trello::Error
      begin
        matching_board = Trello::Board.all.select {|b| b.name.downcase == GitReflow::Config.get('trello.board-id', local: true)}.first
        if matching_board.present?
          GitReflow::Config.set('trello.board-id', matching_board.id, local: true)
          @trello_lists = matching_board.lists
        else
          []
        end
      rescue Trello::Error
        []
      end
    end
  end

  def trello_uses_list?(list_name)
    !GitReflow::Config.get("trello.#{list_name}-list-id", local: true).empty?
  end

  def trello_list(key)
    trello_lists.select {|l| l.name == GitReflow::Config.get("trello.#{key}-list-id", local: true) }.first
  end

  def trello_next_list
    @trello_next_list ||= trello_list('next')
  end

  def trello_in_progress_list
    @trello_current_list ||= trello_list('current')
  end

  def trello_staged_list
    @trello_staged_list ||= trello_list('staged')
  end

  def trello_approved_list
    @trello_approved_list ||= trello_list('approved')
  end

  def trello_completed_list
    @trello_completed_list ||= trello_list('completed')
  end

end
