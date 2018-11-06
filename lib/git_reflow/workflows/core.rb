$LOAD_PATH << File.expand_path(File.realpath(__dir__) + '/../..')
require 'git_reflow/workflow'

module GitReflow
  module Workflows
    # This class contains the core workflow for git-reflow. Going forward, this
    # will act as the base class for customizing and extending git-reflow.
    class Core
      include ::GitReflow::Workflow

      # Reads and evaluates the provided file  in the context of this class
      #
      # @param workflow_path [String] the path of the Workflow file to eval
      def self.load_workflow(workflow_path)
        return unless workflow_path.length > 0 and File.exists?(workflow_path)
        ::GitReflow.logger.debug "Using workflow: #{workflow_path}"
        self.load_raw_workflow(File.read(workflow_path))
      end

      # Evaluates the provided string in the context of this class
      #
      # @param workflow_string [String] the contents of a Workflow file to eval
      def self.load_raw_workflow(workflow_string)
        return if workflow_string.strip.empty?
        ::GitReflow.logger.debug "Evaluating workflow..."
        binding.eval(workflow_string)
      end

      # Sets up the required git configurations that git-reflow depends on.
      #
      # @param [Hash] options the options to run setup with
      # @option options [Boolean] :local (false) whether to configure git-reflow specific to the current project
      # @option options [Boolean] :enterprise (false) whether to configure git-reflow for use with Github Enterprise
      command(:setup, switches: { local: false, enterprise: false}) do |**params|
        reflow_options             = { project_only: params[:local], enterprise: params[:enterprise] }
        existing_git_include_paths = git_config.get('include.path', all: true).split("\n")

        unless File.exist?(git_config::CONFIG_FILE_PATH) or existing_git_include_paths.include?(git_config::CONFIG_FILE_PATH)
          say "We'll walk you through setting up git-reflow's defaults for all your projects.", :notice
          say "In the future, you can run \`git-reflow setup --local\` from the root of any project you want to setup differently.", :notice
          run "touch #{git_config::CONFIG_FILE_PATH}"
          say "Created #{git_config::CONFIG_FILE_PATH} for git-reflow specific configurations.", :notice
          git_config.add "include.path", git_config::CONFIG_FILE_PATH, global: true
          say "Added #{git_config::CONFIG_FILE_PATH} to include.path in $HOME/.gitconfig.", :notice
        end

        choose do |menu|
          menu.header = "Available remote Git Server services"
          menu.prompt = "Which service would you like to use for this project?  "

          menu.choice('GitHub')    { ::GitReflow::GitServer.connect reflow_options.merge({ provider: 'GitHub', silent: false }) }
          menu.choice('BitBucket (team-owned repos only)') { ::GitReflow::GitServer.connect reflow_options.merge({ provider: 'BitBucket', silent: false }) }
        end

        git_config.set "constants.minimumApprovals", ask("Set the minimum number of approvals (leaving blank will require approval from all commenters): "), local: reflow_options[:project_only]
        git_config.set "constants.approvalRegex", ::GitReflow::GitServer::PullRequest::DEFAULT_APPROVAL_REGEX, local: reflow_options[:project_only]

        if git_config.get('core.editor').length <= 0
          git_config.set('core.editor', default_editor, local: reflow_options[:project_only])
          say "Updated git's editor (via git config key 'core.editor') to: #{default_editor}.", :notice
        end
      end
      command_help(
        :setup,
        summary: "Connect your GitServer (e.g. GitHub) account to git-reflow",
        switches: {
          local: "setup GitReflow for the current project only",
          enterprise: "setup GitReflow with a Github Enterprise account",
        }
      )

      # Start a new feature branch
      #
      # @param [Hash] options the options to run start with
      # @option options [String] :base ("master") the name of the base branch you want to checkout your feature from
      # @option options [String] :feature_branch the name of the base branch you want to checkout your feature from
      command(:start, arguments: { feature_branch: nil }, flags: { base: "master" }) do |**params|
        base_branch    = params[:base]
        feature_branch = params[:feature_branch]

        if feature_branch.to_s.strip.empty?
          say "usage: git-reflow start [new-branch-name]", :error
        else
          run_command_with_label "git checkout #{base_branch}"
          run_command_with_label "git pull origin #{base_branch}"
          run_command_with_label "git push origin #{base_branch}:refs/heads/#{feature_branch}"
          run_command_with_label "git checkout --track -b #{feature_branch} origin/#{feature_branch}"
        end
      end
      command_help(
        :start,
        summary: "This will create a new feature branch and setup remote tracking",
        arguments: { new_feature_branch: "name of the new feature branch" },
        flags: { base: "name of a branch you want to branch off of" },
        description: <<LONGTIME
Performs the following:\n
\t$ git checkout <base_branch>\n
\t$ git pull origin <base_branch>\n
\t$ git push origin <base_branch>:refs/heads/[new_feature_branch]\n
\t$ git checkout --track -b [new_feature_branch] origin/[new_feature_branch]\n
LONGTIME
      )

      # Submit a feature branch for review
      #
      # @param [Hash] options the options to run review with
      # @option options [String] :base ("master") the name of the base branch you want to merge your feature into
      # @option options [String] :title (<current-branch-name>) the title of your pull request
      # @option options [String] :message ("") the body of your pull request
      command(:review, arguments: { base: "master" }, flags: { title: nil, message: nil }) do |**params|
        base_branch         = params[:base]
        create_pull_request = true

        fetch_destination base_branch
        begin
          push_current_branch

          existing_pull_request = git_server.find_open_pull_request( from:current_branch, to: base_branch )
          if existing_pull_request
            say "A pull request already exists for these branches:", :notice
            existing_pull_request.display_pull_request_summary
          else
            unless params[:title] || params[:message]
              pull_request_msg_file = "#{git_root_dir}/.git/GIT_REFLOW_PR_MSG"

              File.open(pull_request_msg_file, 'w') do |file|
                begin
                  pr_message = params[:title] || pull_request_template || current_branch
                  file.write(pr_message)
                rescue StandardError => e
                  logger.error "Unable to parse PR template (#{pull_request_msg_file}): #{e.inspect}"
                  file.write(params[:title] || current_branch)
                end
              end

              run("#{git_editor_command} #{pull_request_msg_file}", with_system: true)

              pr_msg = File.read(pull_request_msg_file).split(/[\r\n]|\r\n/).map(&:strip)
              title  = pr_msg.shift

              File.delete(pull_request_msg_file)

              unless pr_msg.empty?
                pr_msg.shift if pr_msg.first.empty?
              end

              params[:title] = title
              params[:message]  = "#{pr_msg.join("\n")}\n"

              say "\nReview your PR:\n"
              say "--------\n"
              say "Title:\n#{params[:title]}\n\n"
              say "Body:\n#{params[:message]}\n"
              say "--------\n"

              create_pull_request = ask("Submit pull request? (Y)") =~ /y/i
            end

            if create_pull_request
              begin
                retries ||= 0
                pull_request = git_server.create_pull_request(
                  title: params[:title] || params[:message],
                  body:  params[:message],
                  head:  "#{remote_user}:#{current_branch}",
                  base:  params[:base]
                )
              rescue Github::Error::UnprocessableEntity
                retry if (retries += 1) < 3
                raise
              end

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
      command_help(
        :review,
        summary: "Pushes your latest feature branch changes to your remote repo and creates a pull request",
        arguments: {
          base: "the branch you want to merge your feature branch into"
        },
        flags: {
          title: "the title of the Pull Request we'll create",
          message: "the body of the Pull Request we'll create"
        }
      )

      # Checks the status of an existing pull request
      #
      # @param [Hash] options the options to run review with
      # @option options [String] :destination_branch ("master") the branch you're merging your feature into
      command(:status, arguments: { destination_branch: "master" }) do |**params|
        pull_request = git_server.find_open_pull_request( :from => current_branch, :to => params[:destination_branch] )

        if pull_request.nil?
          say "No pull request exists for #{current_branch} -> #{params[:destination_branch]}", :notice
          say "Run 'git reflow review #{params[:destination_branch]}' to start the review process", :notice
        else
          say "Here's the status of your review:"
          pull_request.display_pull_request_summary
        end
      end
      command_help(
        :status,
        summary: "Display information about the status of your feature in the review process",
        arguments: {
          destination_branch: "the branch to merge your feature into"
        }
      )

      # Deploys the current branch to a specified server
      #
      # @param [Hash] options the options to run review with
      # @option options [String] :destination_server ("default") the environment server to deploy to (pulled from `git config "reflow.deploy-to-#{destination_server}-command")
      command(:deploy, arguments: { destination_server: "default" }) do |**params|
        destination_server = params[:destination_server] || "default"
        deploy_command = git_config.get("reflow.deploy-to-#{destination_server}-command", local: true)

        # first check is to allow for automated setup
        if deploy_command.empty?
          deploy_command = ask("Enter the command you use to deploy to #{destination_server} (leaving blank will skip deployment)")
        end

        # second check is to see if the user wants to skip
        if deploy_command.empty?
          say "Skipping deployment..."
          false
        else
          git_config.set("reflow.deploy-to-#{destination_server}-command", deploy_command, local: true)
          run_command_with_label(deploy_command, with_system: true)
        end
      end
      command_help(
        :deploy,
        summary: "Deploys the current branch to a specified server",
        arguments: {
          destination_server: 'the environment to deploy to (from: `git config "reflow.deploy-to-#{destination_server}-command"`)'
        }
      )

      # Merge and deploy a feature branch to a staging branch
      command(:stage) do |**params|
        feature_branch_name = current_branch
        staging_branch_name = git_config.get('reflow.staging-branch', local: true)

        if staging_branch_name.empty?
          staging_branch_name = ask("What's the name of your staging branch? (default: 'staging') ")
          staging_branch_name = 'staging' if staging_branch_name.strip == ''
          git_config.set('reflow.staging-branch', staging_branch_name, local: true)
        end

        run_command_with_label "git checkout #{staging_branch_name}"
        run_command_with_label "git pull origin #{staging_branch_name}"

        if run_command_with_label "git merge #{feature_branch_name}", with_system: true
          run_command_with_label "git push origin #{staging_branch_name}"

          staged = self.deploy(destination_server: :staging)

          if staged
            say "Deployed to Staging.", :success
          else
            say "There were issues deploying to staging.", :error
          end
        else
          say "There were issues merging your feature branch to staging.", :error
        end
      end
      command_help(
        :stage,
        summary: "Merge and deploy a feature branch to a staging branch"
      )

      # Deliver a feature branch to a base branch
      #
      # @param [Hash] options the options to run review with
      # @option options [String] :base ("master") the base branch to merge your feature branch into
      # @option options [String] :force (false) whether to force-deliver the feature branch, ignoring any QA checks
      command(:deliver, arguments: { base: "master" }, flags: { merge_method: "squash" }, switches: { force: false, skip_lgtm: false }) do |**params|
        params[:force] = params[:force] || params[:skip_lgtm]
        begin
          existing_pull_request = git_server.find_open_pull_request( from: current_branch, to: params[:base] )

          if existing_pull_request.nil?
            say "No pull request exists for #{remote_user}:#{current_branch}\nPlease submit your branch for review first with \`git reflow review\`", :deliver_halted
          else

            if existing_pull_request.good_to_merge?(force: params[:force])
              # displays current status and prompts user for confirmation
              self.status destination_branch: params[:base]
              existing_pull_request.merge!(params)
            else
              say existing_pull_request.rejection_message, :deliver_halted
            end

          end

        rescue Github::Error::UnprocessableEntity => e
          say "Github Error: #{e.inspect}", :error
        end
      end
      command_help(
        :deliver,
        summary: "deliver your feature branch",
        arguments: {
          base: "the branch to merge this feature into"
        },
        flags: {
          merge_method: "how you want your feature branch merged ('squash', 'merge', 'rebase')"
        },
        switches: {
          force: "skip the lgtm checks and deliver your feature branch",
          skip_lgtm: "skip the lgtm checks and deliver your feature branch"
        },
        description: "merge your feature branch down to your base branch, and cleanup your feature branch"
      )


      # Updates and synchronizes your base branch and feature branch.
      #
      # Performs the following:
      #   $ git checkout <base_branch>
      #   $ git pull <remote_location> <base_branch>
      #   $ git checkout <current_branch>
      #   $ git pull origin <current_branch>
      #   $ git merge <base_branch>
      #
      # @param [Hash] options the options to run review with
      # @option options [String] :remote ("origin") the name of the remote repository to fetch updates from
      # @option options [String] :base ("master") the branch that you want to fetch updates from
      command(:refresh, flags: { remote: 'origin', base: 'master'}) do |**params|
        update_feature_branch(params)
      end
      command_help(
        :refresh,
        summary: "Updates and synchronizes your base branch and feature branch.",
        flags: {
          base: "branch to merge into",
          remote: "remote repository name to fetch updates from",
        },
        description: <<LONGTIME
Performs the following:\n
\t$ git checkout <base_branch>\n
\t$ git pull <remote_location> <base_branch>\n
\t$ git checkout <current_branch>\n
\t$ git pull origin <current_branch>\n
\t$ git merge <base_branch>\n
LONGTIME
      )
    end
  end
end
