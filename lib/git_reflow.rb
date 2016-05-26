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
require 'git_reflow/merge_error'

module GitReflow
  include Sandbox
  include GitHelpers
  extend self

  DEFAULT_EDITOR = "#{ENV['EDITOR']}".freeze || "vi".freeze

  def status(destination_branch)
    pull_request = git_server.find_open_pull_request( :from => current_branch, :to => destination_branch )

    if pull_request.nil?
      say "\nNo pull request exists for #{current_branch} -> #{destination_branch}", :notice
      say "Run 'git reflow review #{destination_branch}' to start the review process", :notice
    else
      say "Here's the status of your review:"
      pull_request.display_pull_request_summary
    end
  end

  def review(options = {})
    options[:base]     ||= 'master'
    create_pull_request   = true

    fetch_destination options[:base]

    begin
      push_current_branch

      existing_pull_request = git_server.find_open_pull_request( from: current_branch, to: options[:base] )
      if existing_pull_request
        say "A pull request already exists for these branches:", :notice
        existing_pull_request.display_pull_request_summary
      else
        unless options[:title] || options[:body]
          pull_request_msg_file = "#{GitReflow.git_root_dir}/.git/GIT_REFLOW_PR_MSG"

          File.open(pull_request_msg_file, 'w') do |file|
            file.write(options[:title] || GitReflow.current_branch)
          end

          GitReflow.run("#{GitReflow.git_editor_command} #{pull_request_msg_file}", with_system: true)

          pr_msg = File.read(pull_request_msg_file).split(/[\r\n]|\r\n/).map(&:strip)
          title  = pr_msg.shift

          File.delete(pull_request_msg_file)

          unless pr_msg.empty?
            pr_msg.shift if pr_msg.first.empty?
          end

          options[:title] = title
          options[:body]  = "#{pr_msg.join("\n")}\n"

          say "\nReview your PR:\n"
          say "--------\n"
          say "Title:\n#{options[:title]}\n\n"
          say "Body:\n#{options[:body]}\n"
          say "--------\n"

          create_pull_request = ask("Submit pull request? (Y)") =~ /y/i
        end

        if create_pull_request
          pull_request = git_server.create_pull_request(title: options[:title] || options[:body],
                                                        body:  options[:body],
                                                        head:  "#{remote_user}:#{current_branch}",
                                                        base:  options[:base])

          say "Successfully created pull request ##{pull_request.number}: #{pull_request.title}\nPull Request URL: #{pull_request.html_url}\n", :success
        else
          say "Review aborted.  No pull request has been created.", :review_halted
        end
      end
    rescue Github::Error::UnprocessableEntity => e
      say "Github Error: #{e.to_s}", :error
    rescue StandardError => e
      say "\nError: #{e.inspect}", :error
    end
  end

  def deliver(options = {})
    base_branch = options[:base] || 'master'

    begin
      existing_pull_request = git_server.find_open_pull_request( :from => current_branch, :to => base_branch )

      if existing_pull_request.nil?
        say "No pull request exists for #{remote_user}:#{current_branch}\nPlease submit your branch for review first with \`git reflow review\`", :deliver_halted
      else

        if existing_pull_request.good_to_merge?(force: options[:skip_lgtm])
          # displays current status and prompts user for confirmation
          self.status base_branch
          existing_pull_request.merge!(options)
        else
          say existing_pull_request.rejection_message, :deliver_halted
        end
      end

    rescue Github::Error::UnprocessableEntity => e
      errors = JSON.parse(e.response_message[:body])
      error_messages = errors["errors"].collect {|error| "GitHub Error: #{error["message"].gsub(/^base\s/, '')}" unless error["message"].nil?}.compact.join("\n")
      say "Github Error: #{error_messages}", :error
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
