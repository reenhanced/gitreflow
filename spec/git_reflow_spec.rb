require 'spec_helper'

describe GitReflow do
  let(:git_server)       { GitReflow::GitServer::GitHub.new {} }
  let(:github)           { Github.new basic_auth: "#{user}:#{password}" }
  let(:user)             { 'reenhanced' }
  let(:password)         { 'shazam' }
  let(:oauth_token_hash) { Hashie::Mash.new({ token: 'a1b2c3d4e5f6g7h8i9j0', note: 'hostname.local git-reflow'}) }
  let(:repo)             { 'repo' }
  let(:base_branch)      { 'master' }
  let(:feature_branch)   { 'new-feature' }
  let(:enterprise_site)  { 'https://github.reenhanced.com' }
  let(:enterprise_api)   { 'https://github.reenhanced.com' }
  let(:hostname)         { 'hostname.local' }

  let(:github_authorizations)  { Github::Client::Authorizations.new }
  let(:existing_pull_requests) { Fixture.new('pull_requests/pull_requests.json').to_json_hashie }
  let(:existing_pull_request)  { GitReflow::GitServer::GitHub::PullRequest.new existing_pull_requests.first }

  before do

    # Stubbing out numlgtm value to test all reviewers in gitconfig file
    allow(GitReflow::Config).to receive(:get).with("constants.minimumApprovals").and_return('')
    allow(GitReflow::Config).to receive(:get).and_call_original

    allow_any_instance_of(HighLine).to receive(:ask) do |terminal, question|
      values = {
        "Please enter your GitHub username: "                                                      => user,
        "Please enter your GitHub password (we do NOT store this): "                               => password,
        "Please enter your Enterprise site URL (e.g. https://github.company.com):"                 => enterprise_site,
        "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):"      => enterprise_api,
        "Would you like to cleanup your feature branch? "                                          => 'yes',
        "Would you like to open it in your browser?"                                               => 'n',
        "This is the current status of your Pull Request. Are you sure you want to deliver? "       => 'yes', 
        "Please enter your delivery commit title: (leaving blank will use default)"                => 'title',
        "Please enter your delivery commit message: (leaving blank will use default)"              => 'message'
      }
     return_value = values[question] || values[terminal]
     question = ""
     return_value
    end
  end

  context :status do
    subject { GitReflow.status(base_branch) }

    before do
      allow(GitReflow).to receive(:current_branch).and_return(feature_branch)
      allow(GitReflow).to receive(:destination_branch).and_return(base_branch)

      allow(Github).to receive(:new).and_return(github)
      allow(GitReflow).to receive(:git_server).and_return(git_server)
      allow(git_server).to receive(:connection).and_return(github)
      allow(git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :target_url).new())
    end

    context 'with no existing pull request' do
      before { allow(git_server).to receive(:find_open_pull_request).with({from: feature_branch, to: base_branch}).and_return(nil) }
      it     { expect{ subject }.to have_output "\n[notice] No pull request exists for #{feature_branch} -> #{base_branch}" }
      it     { expect{ subject }.to have_output "[notice] Run 'git reflow review #{base_branch}' to start the review process" }
    end

    context 'with an existing pull request' do
      before do
        allow(git_server).to receive(:find_open_pull_request).with({from: feature_branch, to: base_branch}).and_return(existing_pull_request)
      end

      it 'displays a summary of the pull request and asks to open it in the browser' do
        expect(existing_pull_request).to receive(:display_pull_request_summary)
        expect(GitReflow).to receive(:ask_to_open_in_browser).with(existing_pull_request.html_url)
        subject
        expect($output).to include "Here's the status of your review:"
      end
    end
  end

  # Github Response specs thanks to:
  # https://github.com/peter-murach/github/blob/master/spec/github/pull_requests_spec.rb
  context :review do
    let(:branch) { 'new-feature' }
    let(:inputs) {
      {
       :title => "Amazing new feature",
       :body => "Please pull this in!",
       :head => "reenhanced:new-feature",
       :base => "master",
       :state => "open"
      }
    }

    let(:github) do
      allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:build).and_return(Struct.new(:state, :description, :url).new)
      stub_github_with({
        :user         => user,
        :password     => password,
        :repo         => repo,
        :branch       => branch,
        :pull         => Hashie::Mash.new(inputs)
      })
    end

    subject { GitReflow.review inputs }

    it "fetches the latest changes to the destination branch" do
      expect(GitReflow).to receive(:fetch_destination).with(inputs[:base])
      expect(github).to receive(:find_open_pull_request).and_return(nil)
      allow(github).to receive(:create_pull_request).and_return(existing_pull_request)
      subject
    end

    it "pushes the latest current branch to the origin repo" do
      expect(GitReflow).to receive(:push_current_branch)
      expect(github).to receive(:find_open_pull_request).and_return(nil)
      allow(github).to receive(:create_pull_request).and_return(existing_pull_request)
      subject
    end

    context "pull request doesn't exist" do
      before do
        allow(github).to receive(:find_open_pull_request).and_return(nil)
      end

      it "successfully creates a pull request if I do not provide one" do
        allow(existing_pull_request).to receive(:title).and_return(inputs[:title])
        expect(github).to receive(:create_pull_request).with(inputs.except(:state).symbolize_keys).and_return(existing_pull_request)
        expect { subject }.to have_output "Successfully created pull request #1: #{inputs[:title]}\nPull Request URL: https://github.com/#{user}/#{repo}/pulls/1\n"
      end

      context "when providing only a title" do
        before do
          inputs[:body] = nil
          allow(existing_pull_request).to receive(:title).and_return(inputs[:title])
        end

        it "successfully creates a pull request with only the provided title" do
          expect(github).to receive(:create_pull_request).with(inputs.except(:state).symbolize_keys).and_return(existing_pull_request)
          expect { subject }.to have_output "Successfully created pull request #1: #{inputs[:title]}\nPull Request URL: https://github.com/#{user}/#{repo}/pulls/1\n"
        end
      end

      context "when providing only a message" do
        before do
          inputs[:title] = nil
          allow(existing_pull_request).to receive(:title).and_return(inputs[:body])
        end

        it "successfully creates a pull request with only the provided title" do
          expected_options = inputs.except(:state)
          expected_options[:title] = inputs[:body]
          expect(github).to receive(:create_pull_request).with(expected_options.symbolize_keys).and_return(existing_pull_request)
          expect { subject }.to have_output "Successfully created pull request #1: #{expected_options[:title]}\nPull Request URL: https://github.com/#{user}/#{repo}/pulls/1\n"
        end
      end
    end

    context "pull request exists" do
      before do
        allow(GitReflow).to receive(:push_current_branch)
        github_error = Github::Error::UnprocessableEntity.new( eval(Fixture.new('pull_requests/pull_request_exists_error.json').to_s) )
        expect(github).to receive(:find_open_pull_request).and_return(existing_pull_request)
        allow(existing_pull_request).to receive(:display_pull_request_summary)
      end

      subject { GitReflow.review inputs }

      it "displays a pull request summary for the existing pull request" do
        expect(existing_pull_request).to receive(:display_pull_request_summary)
        subject
      end

      it "asks to open the pull request in the browser" do
        expect(GitReflow).to receive(:ask_to_open_in_browser).with(existing_pull_request.html_url)
        subject
      end
    end
  end

  context :deliver do
    let(:branch)                { 'new-feature' }
    let(:inputs) {
      {
       :title => "new-feature",
       :message => "message",
       :head => "reenhanced:new-feature"
      }
    }
    let(:merge_response) { {} }
    let!(:github) do
      allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:build).and_return(Struct.new(:state, :description, :url).new)
      stub_github_with({
        :user         => user,
        :password     => password,
        :repo         => repo,
        :branch       => branch,
        :pull         => existing_pull_request
      })
    end

    before do
      allow(GitReflow::GitServer::GitHub).to receive_message_chain(:connection, :pull_requests, :merge).and_return(merge_response)
      allow(merge_response).to receive(:success?).and_return(true)
      allow_any_instance_of(Object).to receive(:strip).and_return("")

      module Kernel
        def system(cmd)
          "call #{cmd}"
        end
      end
    end

    subject { GitReflow.deliver inputs }

    it "looks for a pull request matching the feature branch and destination branch" do
      expect(github).to receive(:find_open_pull_request).with(from: branch, to: 'master')
      subject
    end

    context "and pull request exists for the feature branch to the destination branch" do
      before do
        allow(github).to receive(:build_status).and_return(build_status)
        allow(github).to receive(:find_open_pull_request).and_return(existing_pull_request)
        allow(existing_pull_request).to receive(:has_comments?).and_return(true)
        allow(GitReflow::Config).to receive(:get).with("reflow.always-deliver").and_return("true")
        allow(GitReflow).to receive(:status)

        allow(github).to receive(:reviewers).and_return(['codenamev'])
      end

      context 'and build status is not "success"' do
        let(:build_status) { Hashie::Mash.new({ state: 'failure', description: 'Build resulted in failed test(s)' }) }

        before do
          allow(existing_pull_request).to receive(:build).and_return(build_status)
          allow(existing_pull_request).to receive(:has_comments?).and_return(true)
        end

        it "halts delivery and notifies user of a failed build" do
          expect { subject }.to have_said "#{build_status.description}: #{build_status.target_url}", :deliver_halted
        end

        context 'forces a merge' do
          let(:lgtm_comment_authors) { ['nhance'] }
          before do
            inputs[:skip_lgtm] = true
            allow(existing_pull_request).to receive(:reviewers_pending_response).and_return([])
            allow(existing_pull_request).to receive(:approvals).and_return(lgtm_comment_authors)
            allow(GitReflow).to receive(:append_to_squashed_commit_message)
            allow(GitReflow::Config).to receive(:get).with("reflow.always-cleanup").and_return("true")
          end

          it "checks out the base branch" do
            expect { subject }.to have_run_command("git checkout master")
          end

          it "pulls changes from remote repo to local branch" do
            expect { subject }.to have_run_command("git pull origin master")
          end

          it "pushes the changes to remote repo" do
            expect { subject }.to have_run_command("git push origin master")
          end

          it "deletes the remote feature branch" do
            expect { subject }.to have_run_command("git push origin :new-feature")
          end

          it "deletes the local feature branch" do
            expect { subject }.to have_run_command("git branch -D new-feature")
          end

          it "forces a merge" do
            expect { subject }.to have_said "Merging pull request ##{existing_pull_request.number}: '#{existing_pull_request.title}', from '#{existing_pull_request.head.label}' into '#{existing_pull_request.base.label}'", :notice
            expect { subject }.to have_said "Pull Request successfully merged.", :success
          end
        end
      end

      context 'and build status is nil' do
        let(:build_status) { nil }
        let(:lgtm_comment_authors) { ['nhance'] }

        before do
          # stubbing unrelated results so we can just test that it made it insdide the conditional block
          inputs[:skip_lgtm] = false
          allow(existing_pull_request).to receive(:reviewers_pending_response).and_return([])
          allow(existing_pull_request).to receive(:approvals).and_return(lgtm_comment_authors)
        end

        it "ignores build status when not setup" do
          expect { subject }.to have_said "Pull Request successfully merged.", :success
        end
      end

      context 'and build status is "success"' do
        let(:build_status) { Hashie::Mash.new({ state: 'success' }) }

        context 'and has comments' do
          before do
            inputs[:skip_lgtm] = false
            allow(existing_pull_request).to receive(:has_comments?).and_return(true)
          end

          context 'but there is a LGTM' do
            let(:lgtm_comment_authors) { ['nhance'] }
            before do
              allow(existing_pull_request).to receive(:approvals).and_return(lgtm_comment_authors)
              allow(existing_pull_request).to receive(:reviewers_pending_response).and_return([])
            end

            context "build status failure, testing description and target_url" do
              let(:build_status) { Hashie::Mash.new({ state: 'failure', description: 'Build resulted in failed test(s)', target_url: "www.error.com" }) }

              before do
                allow(existing_pull_request).to receive(:build).and_return(build_status)
                allow(existing_pull_request).to receive(:reviewers).and_return(lgtm_comment_authors)
                allow(existing_pull_request).to receive(:has_comments?).and_return(true)
              end

              it "halts delivery and notifies user of a failed build" do
                expect { subject }.to have_said "#{build_status.description}: #{build_status.url}", :deliver_halted
              end
            end

            context "build status nil" do
              let(:build_status) { nil }

              before do
                allow(github).to receive(:build).and_return(build_status)
                allow(existing_pull_request).to receive(:reviewers_pending_response).and_return([])
                allow(existing_pull_request).to receive(:has_comments_or_approvals).and_return(true)
              end

              it "commits the changes if the build status is nil but has comments/approvals and no pending response" do
                expect{ subject }.to have_said 'Pull Request successfully merged.', :success
              end
            end

            context "and the pull request has no body" do
              let(:first_commit_message) { "We'll do it live." }

              before do
                existing_pull_request.description = ''
                allow(github).to receive(:find_open_pull_request).and_return(existing_pull_request)
                allow(GitReflow).to receive(:get_first_commit_message).and_return(first_commit_message)
                allow(existing_pull_request).to receive(:approvals).and_return(lgtm_comment_authors)
              end
            end

            it "doesn't always deliver" do
              expect(GitReflow::Config).to receive(:get).with("reflow.always-deliver").and_return("false")
              expect { subject }.to have_said "Merge aborted", :deliver_halted
            end

            it "notifies user of the merge and performs it" do
              expect { subject }.to have_said "Merging pull request ##{existing_pull_request.number}: '#{existing_pull_request.title}', from '#{existing_pull_request.head.label}' into '#{existing_pull_request.base.label}'", :notice
            end

            it "commits the changes for the squash merge" do
              expect{ subject }.to have_said 'Pull Request successfully merged.', :success
            end

            context "and cleaning up feature branch" do
              before do
                allow_any_instance_of(HighLine).to receive(:ask) do |terminal, question|
                  values = {
                    "Please enter your GitHub username: "                                                      => user,
                    "Please enter your GitHub password (we do NOT store this): "                               => password,
                    "Please enter your Enterprise site URL (e.g. https://github.company.com):"                 => enterprise_site,
                    "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):"      => enterprise_api,
                    "Would you like to cleanup your feature branch? "                                          => 'yes',
                    "Would you like to open it in your browser?"                                               => 'no',
                    "This is the current status of your Pull Request. Are you sure you want to deliver? "      => 'y', 
                    "Please enter your delivery commit title: (leaving blank will use default)"                => 'title',
                    "Please enter your delivery commit message: (leaving blank will use default)"              => 'message'
                  }
                 return_value = values[question] || values[terminal]
                 question = ""
                 return_value
                end
              end

              context "not always" do
                before do
                  allow(GitReflow::Config).to receive(:get).with("reflow.always-cleanup").and_return("false")
                end

                it "checks out the base branch" do
                  expect { subject }.to have_run_command("git checkout master")
                end

                it "pulls changes from remote repo to local branch" do
                  expect { subject }.to have_run_command("git pull origin master")
                end

                it "deletes the remote feature branch" do
                  expect { subject }.to have_run_command("git push origin :new-feature")
                end

                it "deletes the local feature branch" do
                  expect { subject }.to have_run_command("git branch -D new-feature")
                end
              end

              context "always" do
                before do
                  allow(GitReflow::Config).to receive(:get).with("reflow.always-cleanup").and_return("true")
                end

                it "checks out the base branch" do
                  expect { subject }.to have_run_command("git checkout master")
                end

                it "pulls changes from remote repo to local branch" do
                  expect { subject }.to have_run_command("git pull origin master")
                end

                it "deletes the remote feature branch" do
                  expect { subject }.to have_run_command("git push origin :new-feature")
                end

                it "deletes the local feature branch" do
                  expect { subject }.to have_run_command("git branch -D new-feature")
                end
              end

            end

            context "and not cleaning up feature branch" do
              before do
                allow_any_instance_of(HighLine).to receive(:ask) do |terminal, question|
                  values = {
                    "Please enter your GitHub username: "                                                      => user,
                    "Please enter your GitHub password (we do NOT store this): "                               => password,
                    "Please enter your Enterprise site URL (e.g. https://github.company.com):"                 => enterprise_site,
                    "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):"      => enterprise_api,
                    "Would you like to cleanup your feature branch? "                                          => 'no',
                    "Would you like to open it in your browser?"                                               => 'no',
                    "This is the current status of your Pull Request. Are you sure you want to deliver? "      => 'y', 
                    "Please enter your delivery commit title: (leaving blank will use default)"                => 'title',
                    "Please enter your delivery commit message: (leaving blank will use default)"              => 'message'
                  }
                 return_value = values[question] || values[terminal]
                 question = ""
                 return_value
                end
              end

              it "does checkout the local base branch" do
                expect { subject }.to have_run_command("git checkout master")
              end

              it "does update the local repo with the new squash merge" do
                expect { subject }.to have_run_command('git pull origin master')
              end

              it "doesn't delete the feature branch on the remote repo" do
                expect { subject }.to_not have_run_command('git push origin :new-feature')
              end

              it "doesn't delete the local feature branch" do
                expect { subject }.to_not have_run_command('git branch -D new-feature')
              end

              it "provides instructions to undo the steps taken" do
                expect { subject }.to have_said("To reset and go back to your branch run \`git reset --hard origin/master && git checkout new-feature\`")
              end
            end
          end

          context 'but there are still unaddressed comments' do
            let(:open_comment_authors) { ['nhance', 'codenamev'] }
            before { allow(existing_pull_request).to receive(:reviewers_pending_response).and_return(open_comment_authors) }
            it "notifies the user to get their code reviewed" do
              expect { subject }.to have_said "You still need a LGTM from: #{open_comment_authors.join(', ')}", :deliver_halted
            end
          end
        end

        context 'but has no comments' do
          before do
            allow(existing_pull_request).to receive(:has_comments?).and_return(false)
            allow(existing_pull_request).to receive(:approvals).and_return([])
            allow(existing_pull_request).to receive(:reviewers_pending_response).and_return([])
          end

          it "notifies the user to get their code reviewed" do
            expect { subject }.to have_said "Your code has not been reviewed yet.", :deliver_halted
          end
        end

        it "successfully finds a pull request for the current feature branch" do
          allow(existing_pull_request).to receive(:good_to_merge?).and_return(true)
          allow(existing_pull_request).to receive(:approvals).and_return(["Simon"])
          allow(existing_pull_request).to receive(:title).and_return(inputs[:title])
          expect { subject }.to have_said "Merging pull request #1: 'new-feature', from 'new-feature' into 'master'", :notice
        end

        it "merges and squashes the feature branch into the master branch" do
          allow(existing_pull_request).to receive(:good_to_merge?).and_return(true)
          allow(existing_pull_request).to receive(:approvals).and_return(["Simon"])
          allow(existing_pull_request).to receive(:title).and_return(inputs[:title])
          expect(existing_pull_request).to receive(:merge!).and_return(true)
          subject
        end
      end
    end

    context "and no pull request exists for the feature branch to the destination branch" do
      before { allow(github).to receive(:find_open_pull_request).and_return(nil) }

      it "notifies the user of a missing pull request" do
        expect { subject }.to have_said "No pull request exists for #{user}:#{branch}\nPlease submit your branch for review first with \`git reflow review\`", :deliver_halted
      end
    end
  end

  context ".deploy(destination)" do
    let(:deploy_command) { "bundle exec cap #{destination} deploy" }
    subject              { GitReflow.deploy(destination) }

    before do
      stub_command_line_inputs({
        "Enter the command you use to deploy to #{destination} (leaving blank will skip deployment)" => "bundle exec cap #{destination} deploy"
      })
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

    context "production" do
      let(:destination) { "production" }

      it "sets the local git-config for reflow.deploy-to-staging-command" do
        expect(GitReflow::Config).to receive(:set).with('reflow.deploy-to-production-command', deploy_command, local: true)
        subject
      end

      it "runs the staging deploy command" do
        expect { subject }.to have_run_command(deploy_command)
      end
    end
  end
end
