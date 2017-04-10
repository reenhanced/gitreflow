require 'spec_helper'

describe GitReflow::Workflows::Core do
  let(:feature_branch)            { 'new-feature' }
  let(:existing_pull_requests)    { Fixture.new('pull_requests/pull_requests.json').to_json_hashie }
  let(:existing_gh_pull_request)  { GitReflow::GitServer::GitHub::PullRequest.new existing_pull_requests.first }
  let(:pull_request_message_file) { "#{GitReflow.git_root_dir}/.git/GIT_REFLOW_PR_MSG" }
  let(:workflow) { GitReflow::Workflows::Core.new }

  before do
    allow(GitReflow).to receive(:current_branch).and_return(feature_branch)
  end

  describe ".setup" do
    subject { workflow.setup }

    before do
      allow(File).to receive(:exist?).and_return(false)
      stub_command_line_inputs({
        'Set the minimum number of approvals (leaving blank will require approval from all commenters): ' => ''
      })
    end

    specify { expect { subject }.to have_run_command_silently "git config -f #{GitReflow::Config::CONFIG_FILE_PATH} --replace-all core.editor \"#{GitReflow.default_editor}\"" }
    specify { expect { subject }.to have_said "Updated git's editor (via git config key 'core.editor') to: #{GitReflow.default_editor}.", :info, :yellow }

    context "core.editor git config has already been set" do
      before  do
        allow(GitReflow::Config).to receive(:get) { "" }
        allow(GitReflow::Config).to receive(:get).with('core.editor').and_return('emacs')
      end

      specify { expect { subject }.to_not have_run_command_silently "git config -f #{GitReflow::Config::CONFIG_FILE_PATH} --replace-all core.editor \"#{GitReflow.default_editor}\"" }
    end

    context "git-reflow has not been setup before" do
      it "notifies the user of global setup" do
        expect { subject }.to have_said "We'll walk you through setting up git-reflow's defaults for all your projects."
        expect { subject }.to have_said "In the future, you can run \`git-reflow setup\` from the root of any project you want to setup differently."
        expect { subject }.to have_said "To adjust these settings globally, you can run \`git-reflow setup --global\`."
      end

      it "creates a .gitconfig.reflow file and includes it in the user's global git config" do
        expect { subject }.to have_run_command_silently "touch #{GitReflow::Config::CONFIG_FILE_PATH}"
        expect { subject }.to have_run_command_silently "git config --global --add include.path \"#{GitReflow::Config::CONFIG_FILE_PATH}\""

        expect { subject }.to have_said "Created #{GitReflow::Config::CONFIG_FILE_PATH} for git-reflow specific configurations.", :info, :yellow
        expect { subject }.to have_said "Added #{GitReflow::Config::CONFIG_FILE_PATH} to include.path in $HOME/.gitconfig.", :info, :yellow
      end

      it "sets the default approval minimum and regex" do
        expect { subject }.to have_run_command_silently "git config -f #{GitReflow::Config::CONFIG_FILE_PATH} --replace-all constants.minimumApprovals \"\""
        expect { subject }.to have_run_command_silently "git config -f #{GitReflow::Config::CONFIG_FILE_PATH} --replace-all constants.approvalRegex \"#{GitReflow::GitServer::PullRequest::DEFAULT_APPROVAL_REGEX}\""
      end

      context "when setting a custom approval minimum" do
        before do
          stub_command_line_inputs({
            'Set the minimum number of approvals (leaving blank will require approval from all commenters): ' => '3'
          })
        end

        specify { expect { subject }.to have_run_command_silently "git config -f #{GitReflow::Config::CONFIG_FILE_PATH} --replace-all constants.minimumApprovals \"3\"" }
      end
    end

    context "git-reflow has been setup before" do
      before do
        allow(File).to receive(:exist?).and_return(true)
      end

      it "doesn't create another .gitconfig.reflow file" do
        expect { subject }.to_not have_run_command "touch #{GitReflow::Config::CONFIG_FILE_PATH}"
        expect { subject }.to_not have_said "Created #{GitReflow::Config::CONFIG_FILE_PATH} for git-reflow specific configurations.", :info, :yellow
      end

      it "doesn't add the .gitconfig.reflow file to the git-config include path" do
        expect { subject }.to_not have_run_command_silently "git config --global --add include.path \"#{GitReflow::Config::CONFIG_FILE_PATH}\""

        expect { subject }.to_not have_said "Added #{GitReflow::Config::CONFIG_FILE_PATH} to include.path in $HOME/.gitconfig.", :info, :yellow
      end
    end
  end

  describe ".start" do
    let(:feature_branch) { 'new_feature' }
    subject              { workflow.start feature_branch }

    it "updates the local repo and starts creates a new branch" do
      expect { subject }.to have_run_commands_in_order [
        "git checkout master",
        "git pull origin master",
        "git push origin master:refs/heads/#{feature_branch}",
        "git checkout --track -b #{feature_branch} origin/#{feature_branch}"
      ]
    end

    context "but no branch name is provided" do
      let(:feature_branch) { "" }

      it "doesn't run any commands and returns usage" do
        expect { subject }.to_not have_run_command "git checkout master"
        expect { subject }.to_not have_run_command "git pull origin master"
        expect { subject }.to_not have_run_command "git push origin master:refs/heads/#{feature_branch}"
        expect { subject }.to_not have_run_command "git checkout --track -b #{feature_branch} origin/#{feature_branch}"
        expect { subject }.to have_said "usage: git-reflow start [new-branch-name]", :info, :red
      end
    end

    it "starts from a different base branch when one is supplied" do
      workflow.options = { base: 'development' }
      expect { workflow.start feature_branch }.to have_run_commands_in_order [
        "git checkout development",
        "git pull origin development",
        "git push origin development:refs/heads/#{feature_branch}",
        "git checkout --track -b #{feature_branch} origin/#{feature_branch}"
      ]
    end
  end

  describe ".review" do
    let(:base_branch)    { nil }
    let(:feature_branch) { 'new-feature' }
    let(:user)           { 'reenhanced' }
    let(:password)       { 'shazam' }
    let(:repo)           { 'repo' }
    let(:options)        { {} }

    before do
      allow(GitReflow).to receive(:remote_user).and_return(user)
      allow(GitReflow).to receive(:git_server).and_return(GitReflow::GitServer)
      allow(GitReflow.git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :url, :target_url).new)
      allow(GitReflow.git_server).to receive(:find_open_pull_request).and_return(nil)
      allow(GitReflow.git_server).to receive(:create_pull_request).and_return(existing_gh_pull_request)
      allow(File).to receive(:open).with(pull_request_message_file, 'w')
      allow(File).to receive(:read).with(pull_request_message_file).and_return("bingo")
      allow(File).to receive(:delete)

      stub_command_line_inputs({
        "Submit pull request? (Y)" => ""
      })
    end

    subject do
      workflow.options = options
      workflow.review(base_branch)
    end

    it "fetches updates to the base branch" do
      expect { subject }.to have_run_command "git fetch origin master"
    end

    it "pushes the current branch to the remote repo" do
      expect { subject }.to have_run_command "git push origin #{feature_branch}"
    end

    it "uses the current branch name as the text for the PR" do
      fake_file = double
      expect(File).to receive(:open).with(pull_request_message_file, "w").and_yield(fake_file)
      expect(fake_file).to receive(:write).with(GitReflow.current_branch)
      subject
    end

    it "opens the pull request file for modification" do
      allow(File).to receive(:open).with(pull_request_message_file, 'w')
      expect { subject }.to have_run_command "#{GitReflow.git_editor_command} #{pull_request_message_file}"
    end

    it "reads the file then cleans up the temporary pull request message file" do
      expect(File).to receive(:read).with(pull_request_message_file)
      expect(File).to receive(:delete).with(pull_request_message_file)
      subject
    end

    it "displays a review of the PR before submitting it" do
      expect { subject }.to have_said "\nReview your PR:\n"
      expect { subject }.to have_said "Title:\nbingo\n\n"
      expect { subject }.to have_said "Body:\n\n\n"
    end

    context "and a PR template exists" do
      let(:template_content) { "hey now" }
      before do
        allow(GitReflow).to receive(:pull_request_template).and_return(template_content)
      end

      it "uses the template's content for the PR" do
        fake_file = double
        expect(File).to receive(:open).with(pull_request_message_file, "w").and_yield(fake_file)
        expect(fake_file).to receive(:write).with(template_content)
        subject
      end

    end

    context "providing a base branch" do
      let(:base_branch) { "development" }

      before do
        stub_command_line_inputs({
          'Submit pull request? (Y)' => 'yes'
        })
      end

      it "creates a pull request using the custom base branch" do
        expect(GitReflow.git_server).to receive(:create_pull_request).with({
          title: 'bingo',
          body: "\n",
          head: "#{user}:#{feature_branch}",
          base: base_branch
        })
        subject
      end
    end

    context "providing only a title" do
      let(:options) {{ title: "Amazing new feature" }}

      before do
        stub_command_line_inputs({
          'Submit pull request? (Y)' => 'yes'
        })
      end

      it "creates a pull request with only the given title" do
        expect(GitReflow.git_server).to receive(:create_pull_request).with({
          title: options[:title],
          body: nil,
          head: "#{user}:#{feature_branch}",
          base: 'master'
        })
        subject
      end

      it "does not bother opening any template file" do
        expect(File).to_not receive(:open)
        expect(File).to_not receive(:read)
        expect(File).to_not receive(:delete)
        subject
      end
    end

    context "providing only a body" do
      let(:options) {{ body:  "Please pull this in!" }}

      before do
        stub_command_line_inputs({
          'Submit pull request? (Y)' => 'yes'
        })
      end

      it "creates a pull request with the body as both title and body" do
        expect(GitReflow.git_server).to receive(:create_pull_request).with({
          title: options[:body],
          body: options[:body],
          head: "#{user}:#{feature_branch}",
          base: 'master'
        })
        subject
      end
    end

    context "providing both title and body" do
      let(:options) {{ title: "Amazing new feature", body:  "Please pull this in!" }}

      before do
        stub_command_line_inputs({
          'Submit pull request? (Y)' => 'yes'
        })
      end

      it "creates a pull request with only the given title" do
        expect(GitReflow.git_server).to receive(:create_pull_request).with({
          title: options[:title],
          body: options[:body],
          head: "#{user}:#{feature_branch}",
          base: 'master'
        })
        subject
      end
    end

    context "with existing pull request" do
      before do
        expect(GitReflow.git_server).to receive(:find_open_pull_request).and_return(existing_gh_pull_request)
        allow(existing_gh_pull_request).to receive(:display_pull_request_summary)
      end

      specify { expect{subject}.to have_said "A pull request already exists for these branches:", :info, :yellow }

      it "displays a notice that an existing PR exists" do
        expect(existing_gh_pull_request).to receive(:display_pull_request_summary)
        subject
      end
    end

    context "approving PR submission" do
      before do
        stub_command_line_inputs({
          'Submit pull request? (Y)' => 'yes'
        })
      end

      it "creates a pull request" do
        expect(GitReflow.git_server).to receive(:create_pull_request).with({
          title: 'bingo',
          body: "\n",
          head: "#{user}:#{feature_branch}",
          base: 'master'
        })
        subject
      end

      it "notifies the user that the pull request was created" do
        expect(GitReflow.git_server).to receive(:create_pull_request).and_return(existing_gh_pull_request)
        expect{ subject }.to have_said "Successfully created pull request ##{existing_gh_pull_request.number}: #{existing_gh_pull_request.title}\nPull Request URL: #{existing_gh_pull_request.html_url}\n", :info, :green
      end
    end

    context "aborting during PR template review" do
      before do
        stub_command_line_inputs({
          'Submit pull request? (Y)' => 'no'
        })
      end

      it "does not create a pull request" do
        expect(GitReflow.git_server).to_not receive(:create_pull_request)
        subject
      end

      it "notifies the user that the review was aborted" do
        expect { subject }.to have_said "Review aborted.  No pull request has been created.", :info, :red
      end
    end
  end

  describe ".status" do
    let(:feature_branch)     { 'new-feature' }
    let(:destination_branch) { nil }

    subject { workflow.status destination_branch }

    before do
      allow(GitReflow).to receive(:git_server).and_return(GitReflow::GitServer)
      allow(GitReflow.git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :url, :target_url).new)
      allow(GitReflow).to receive(:current_branch).and_return(feature_branch)
      allow(existing_gh_pull_request).to receive(:display_pull_request_summary)
    end

    context "with no existing pull request" do
      before { allow(GitReflow.git_server).to receive(:find_open_pull_request).with({from: feature_branch, to: 'master'}).and_return(nil) }
      it     { expect{ subject }.to have_said "No pull request exists for #{feature_branch} -> master", :info, :yellow }
      it     { expect{ subject }.to have_said "Run 'git reflow review master' to start the review process", :info, :yellow }
    end

    context "with an existing pull request" do
      let(:destination_branch) { 'master' }
      before do
        allow(GitReflow.git_server).to receive(:find_open_pull_request).and_return(existing_gh_pull_request)
      end

      it "displays a summary of the pull request" do
        expect(existing_gh_pull_request).to receive(:display_pull_request_summary)
        expect{ subject }.to have_said "Here's the status of your review:"
      end

      context "with custom destination branch" do
        let(:destination_branch) { 'develop' }

        it "uses the custom destination branch to lookup the pull request" do
          expect(GitReflow.git_server).to receive(:find_open_pull_request).with({from: feature_branch, to: destination_branch}).and_return(existing_gh_pull_request)
          subject
        end
      end
    end
  end

  describe ".deploy" do
    let(:deploy_command) { "bundle exec cap #{destination} deploy" }
    let(:destination)    { nil }
    subject              { workflow.deploy(destination) }

    before do
      stub_command_line_inputs({
        "Enter the command you use to deploy to default (leaving blank will skip deployment)" => "bundle exec cap deploy",
        "Enter the command you use to deploy to #{destination} (leaving blank will skip deployment)" => "bundle exec cap #{destination} deploy"
      })
    end

    it "sets the local git-config for reflow.deploy-to-default-command" do
      expect(GitReflow::Config).to receive(:set).with('reflow.deploy-to-default-command', deploy_command.squeeze, local: true)
      subject
    end

    it "runs the staging deploy command" do
      expect { subject }.to have_run_command(deploy_command.squeeze)
    end

    context "staging" do
      let(:destination) { "staging" }

      it "sets the local git-config for reflow.deploy-to-staging-command" do
        expect(GitReflow::Config).to receive(:set).with('reflow.deploy-to-staging-command', deploy_command, local: true)
        subject
      end

      it "runs the staging deploy command" do
        expect { subject }.to have_run_command(deploy_command)
      end
    end
  end

  describe ".stage" do
    let(:feature_branch) { 'new-feature' }

    subject { workflow.stage }

    before do
      allow(GitReflow).to receive(:current_branch).and_return(feature_branch)
      allow(GitReflow::Config).to receive(:get).and_call_original
      allow(workflow).to receive(:deploy)
      stub_command_line_inputs({
        "Enter the command you use to deploy to staging (leaving blank will skip deployment)" => "bundle exec cap staging deploy"
      })
    end

    it "checks out and updates the staging branch" do
      expect(GitReflow::Config).to receive(:get).with('reflow.staging-branch', local: true).and_return('staging')
      expect { subject }.to have_run_commands_in_order([
        "git checkout staging",
        "git pull origin staging",
        "git merge #{feature_branch}",
        "git push origin staging"
      ])
    end

    context "merge is not successful" do
      before do
        allow(GitReflow::Config).to receive(:get).with('reflow.staging-branch', local: true).and_return('staging')
        allow(GitReflow).to receive(:run_command_with_label).and_call_original
        expect(GitReflow).to receive(:run_command_with_label).with("git merge #{feature_branch}", with_system: true).and_return(false)
      end

      it "notifies the user of unsuccessful merge" do
        expect { subject }.to have_said "There were issues merging your feature branch to staging.", :error, :red
      end

      it "does not push any changes to the remote repo" do
        expect { subject }.to_not have_run_command "git push origin staging"
      end

      it "does not deploy to staging" do
        expect(workflow).to_not receive(:deploy)
        subject
      end
    end

    context "merge is successful" do
      before do
        allow(GitReflow::Config).to receive(:get).with('reflow.staging-branch', local: true).and_return('staging')
        allow(GitReflow).to receive(:run_command_with_label).and_call_original
        expect(GitReflow).to receive(:run_command_with_label).with("git merge #{feature_branch}", with_system: true).and_return(true).and_call_original
      end

      specify { expect{ subject }.to have_run_command "git push origin staging" }

      context "and deployment is successful" do
        before  { expect(workflow).to receive(:deploy).with(:staging).and_return(true) }
        specify { expect{ subject }.to have_said "Deployed to Staging.", :info, :green }
      end

      context "but deployment is not successful" do
        before  { allow(workflow).to receive(:deploy).with(:staging).and_return(false) }
        specify { expect{ subject }.to have_said "There were issues deploying to staging.", :error, :red }
      end
    end

    context "no staging branch has been setup" do
      before do
        allow(GitReflow::Config).to receive(:get).with('reflow.staging-branch', local: true).and_return('')
        stub_command_line_inputs({
          "What's the name of your staging branch? (default: 'staging') " => "bobby"
          })
      end

      it "sets the reflow.staging-branch git config to 'staging'" do
        expect(GitReflow::Config).to receive(:set).with("reflow.staging-branch", "bobby", local: true)
        subject
      end

      it "checks out and updates the staging branch" do
        allow(GitReflow::Config).to receive(:set).with("reflow.staging-branch", "bobby", local: true)
        expect { subject }.to have_run_commands_in_order([
          "git checkout bobby",
          "git pull origin bobby",
          "git merge #{feature_branch}",
          "git push origin bobby"
        ])
      end

      context "and I don't enter one in" do
        before do
          stub_command_line_inputs({
            "What's the name of your staging branch? (default: 'staging') " => ""
          })
        end

        it "sets the reflow.staging-branch git config to 'staging'" do
          expect { subject }.to have_run_command_silently "git config --replace-all reflow.staging-branch \"staging\""
        end

        it "checks out and updates the staging branch" do
          expect { subject }.to have_run_commands_in_order([
            "git checkout staging",
            "git pull origin staging",
            "git merge #{feature_branch}",
            "git push origin staging"
          ])
        end
      end
    end
  end

  describe ".deliver" do
    let(:feature_branch) { 'new-feature' }
    let(:user)           { 'reenhanced' }
    let(:repo)           { 'repo' }

    subject { workflow.deliver }

    before do
      allow(GitReflow).to receive(:git_server).and_return(GitReflow::GitServer)
      allow(GitReflow).to receive(:remote_user).and_return(user)
      allow(GitReflow).to receive(:current_branch).and_return(feature_branch)
      allow(GitReflow.git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :url, :target_url).new)
    end

    context "pull request does not exist" do
      before  { allow(GitReflow.git_server).to receive(:find_open_pull_request).with( from: feature_branch, to: 'master').and_return(nil) }
      specify { expect{ subject }.to have_said "No pull request exists for #{user}:#{feature_branch}\nPlease submit your branch for review first with \`git reflow review\`", :info, :red }
    end

    context "pull request exists" do
      before do
        allow(GitReflow.git_server).to receive(:find_open_pull_request).with( from: feature_branch, to: 'master').and_return(existing_gh_pull_request)
        allow(workflow).to receive(:status)
      end

      context "and PR passes all QA checks" do
        before { allow(existing_gh_pull_request).to receive(:good_to_merge?).and_return(true) }

        it "displays the status of the PR" do
          allow(existing_gh_pull_request).to receive(:merge!)
          expect(workflow).to receive(:status).with("master")
          subject
        end

        it "merges the feature branch" do
          expect(existing_gh_pull_request).to receive(:merge!)
          subject
        end

        context "but there is an error from the git server" do
          let(:github_error) { Github::Error::UnprocessableEntity.new(eval(Fixture.new('pull_requests/pull_request_exists_error.json').to_s)) }
          before do
            allow(existing_gh_pull_request).to receive(:merge!).and_raise github_error
          end

          it "notifies the user of the error" do
            expect { subject }.to have_said "Github Error: #{github_error.inspect}", :error, :red
          end
        end
      end

      context "and PR fails some QA checks" do
        before do
          allow(existing_gh_pull_request).to receive(:good_to_merge?).and_return(false)
          allow(existing_gh_pull_request).to receive(:rejection_message).and_return("I think you need a hug.")
        end

        it "does not merge the feature branch" do
          expect(existing_gh_pull_request).to_not receive(:merge!)
          subject
        end

        it "does not display the status of the PR" do
          expect(workflow).to_not receive(:status).with("master")
          subject
        end

        it "notifies the user of the reason the merge is unsafe" do
          expect { subject }.to have_said "I think you need a hug.", :info, :red
        end

        context "but forcing the deliver" do
          subject do
            workflow.options = { force: true }
            workflow.deliver
          end

          before do
            allow(existing_gh_pull_request).to receive(:good_to_merge?).with(force: true).and_return(true)
            allow(existing_gh_pull_request).to receive(:merge!).with(force: true, base: 'master', skip_lgtm: true)
          end

          it "displays the status of the PR" do
            expect(workflow).to receive(:status).with("master")
            subject
          end

          it "merges the feature branch anyway" do
            expect(existing_gh_pull_request).to receive(:merge!).with(force: true, base: 'master', skip_lgtm: true)
            subject
          end
        end
      end

      context "and using a custom base branch" do
        subject { workflow.deliver 'development' }
        before do
          expect(GitReflow.git_server).to receive(:find_open_pull_request).with( from: feature_branch, to: 'development').and_return(existing_gh_pull_request)
          allow(existing_gh_pull_request).to receive(:good_to_merge?).and_return(true)
        end


        it "displays the status of the PR" do
          allow(existing_gh_pull_request).to receive(:merge!).with(base: 'development')
          expect(workflow).to receive(:status).with("development")
          subject
        end

        it "merges the feature branch" do
          expect(existing_gh_pull_request).to receive(:merge!).with(base: 'development')
          subject
        end
      end
    end
  end

  describe ".refresh" do
    subject { workflow.refresh }

    it "updates the feature branch with default remote repo and base branch" do
      expect(GitReflow).to receive(:update_feature_branch).with("remote" => "origin", "base" => "master")
      subject
    end

    context "providing a custom base branch" do
      subject do
        workflow.options = { base: "development" }
        workflow.refresh
      end

      it "updates the feature branch with default remote repo and base branch" do
        expect(GitReflow).to receive(:update_feature_branch).with(remote: "origin", base: "development")
        subject
      end
    end

    context "provding a custom remote repo" do
      subject do
        workflow.options = { remote: "upstream" }
        workflow.refresh
      end

      it "updates the feature branch with default remote repo and base branch" do
        expect(GitReflow).to receive(:update_feature_branch).with(remote: "upstream", base: "master")
        subject
      end
    end

    context "providing a custom base branch and remote repo" do
      subject do
        workflow.options = { remote: "upstream", base: "development" }
        workflow.refresh
      end

      it "updates the feature branch with default remote repo and base branch" do
        expect(GitReflow).to receive(:update_feature_branch).with(remote: "upstream", base: "development")
        subject
      end
    end
  end
end
