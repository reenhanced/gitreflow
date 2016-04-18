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

    # Stubbing out minimum_approvals value to test 2 LGTM reviewers in gitconfig file
    allow(GitReflow::Config).to receive(:get).with("constants.minimumApprovals").and_return("2")
    allow(GitReflow::Config).to receive(:get).and_call_original

    allow_any_instance_of(HighLine).to receive(:ask) do |terminal, question|
      values = {
        "Please enter your GitHub username: "                                                      => user,
        "Please enter your GitHub password (we do NOT store this): "                               => password,
        "Please enter your Enterprise site URL (e.g. https://github.company.com):"                 => enterprise_site,
        "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):"      => enterprise_api,
        "Would you like to cleanup your feature branch? "                                          => 'yes',
        "Would you like to open it in your browser?"                                               => 'n',
        "This is the current status of your Pull Request. Are you sure you want to deliver? "      => 'y', 
        "Please enter your delivery commit title: (leaving blank will use default)"                => 'title',
        "Please enter your delivery commit message: (leaving blank will use default)"              => 'message'
      }
     return_value = values[question] || values[terminal]
     question = ""
     return_value
    end
  end

  context :deliver do
    let(:branch)                { 'new-feature' }
    let(:inputs) { 
      { :title => "new-feature", 
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
      allow_any_instance_of(Object).to receive(:strip).and_return("")
      allow(GitReflow::GitServer::GitHub).to receive_message_chain(:connection, :pull_requests, :merge).and_return(merge_response)
      allow(merge_response).to receive(:success?).and_return(true)

      # Stubs out the http response to github api
      allow(GitReflow::GitServer::GitHub).to receive_message_chain(:connection, :pull_requests, :merge).and_return(merge_response)
      allow(merge_response).to receive(:success?).and_return(true);

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
        expect(github).to receive(:find_open_pull_request).and_return(existing_pull_request)
        allow(existing_pull_request).to receive(:has_comments?).and_return(true)
        allow(github).to receive(:reviewers).and_return(['codenamev'])
        allow(existing_pull_request).to receive(:approvals).and_return(["Simon", "John"])
        allow(existing_pull_request).to receive_message_chain(:last_comment, :match).and_return(true)
        allow(GitReflow::Config).to receive(:get).with("reflow.always-deliver").and_return("true")
        allow(GitReflow).to receive(:status)
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
          before do
            inputs[:skip_lgtm] = true 
            allow(existing_pull_request).to receive(:has_comments?).and_return(true)
            allow(existing_pull_request).to receive(:reviewers).and_return([])
            allow(existing_pull_request).to receive(:reviewers_pending_response).and_return([])
            allow(existing_pull_request).to receive(:approvals).and_return(['simonzhu24'])
            allow(GitReflow).to receive(:append_to_squashed_commit_message)
            allow(GitReflow::Config).to receive(:get).with("reflow.always-cleanup").and_return("true")
          end

          it "forces a merge" do
            expect(existing_pull_request).to receive(:good_to_merge?).and_return(true)
            expect { subject }.to have_said "Merging pull request ##{existing_pull_request.number}: '#{existing_pull_request.title}', from '#{existing_pull_request.head.label}' into '#{existing_pull_request.base.label}'", :notice
            expect { subject }.to have_said "Pull Request successfully merged.", :success
          end
        end
      end

      context 'and build status is nil' do
        let(:build_status) { nil }

        before do
          # stubbing unrelated results so we can just test that it made it insdide the conditional block
          inputs[:skip_lgtm] = false
          allow(existing_pull_request).to receive(:has_comments?).and_return(true)
          allow(existing_pull_request).to receive(:reviewers).and_return([])
          allow(existing_pull_request).to receive(:reviewers_pending_response).and_return([])
          allow(existing_pull_request).to receive(:approvals).and_return(['simonzhu24'])
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

          context 'but there are 2 LGTMs and irrelevant last comment' do
            let(:lgtm_comment_authors) { ['nhance', 'Simon'] }
            before do
              allow(existing_pull_request).to receive(:build).and_return(build_status)
              allow(existing_pull_request).to receive(:approvals).and_return(lgtm_comment_authors)
              allow(GitReflow::GitServer::PullRequest).to receive(:minimum_approvals).and_return("2")
              allow(existing_pull_request).to receive(:reviewers_pending_response).and_return([])
              allow(existing_pull_request).to receive_message_chain(:last_comment, :match).and_return(nil)
            end

            context "and the pull request has no body" do
              let(:first_commit_message) { "We'll do it live." }

              before do
                existing_pull_request.description = ''
                allow(github).to receive(:find_open_pull_request).and_return(existing_pull_request)
                allow(GitReflow).to receive(:get_first_commit_message).and_return(first_commit_message)
                allow(existing_pull_request).to receive(:reviewers).and_return(lgtm_comment_authors)
              end
            end

            it "doesn't notify user of the merge and performs it" do
              expect { subject }.to_not have_said "Merging pull request ##{existing_pull_request.number}: '#{existing_pull_request.title}', from '#{existing_pull_request.head.label}' into '#{existing_pull_request.base.label}'"
            end

            it "doesn't update the destination branch" do
              expect(GitReflow).to receive(:update_destination).with('master').never
              subject
            end

            context "and doesn't clean up feature branch" do
              before do
                allow_any_instance_of(HighLine).to receive(:ask) do |terminal, question|
                  values = {
                    "Please enter your GitHub username: "                                                      => user,
                    "Please enter your GitHub password (we do NOT store this): "                               => password,
                    "Please enter your Enterprise site URL (e.g. https://github.company.com):"                 => enterprise_site,
                    "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):"      => enterprise_api,
                    "Would you like to cleanup your feature branch?"                                           => 'yes',
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
                  allow(GitReflow::Config).to receive(:get) { "false" }
                end

                it "doesn't push local squash merged base branch to remote repo" do
                  expect { subject }.to_not have_run_command("git push origin master")
                end

                it "doesn't delete the remote feature branch" do
                  expect { subject }.to_not have_run_command("git push origin :new-feature")
                end

                it "doesn't delete the local feature branch" do
                  expect { subject }.to_not have_run_command("git branch -D new-feature")
                end
              end

              context "always" do
                before do
                  allow(GitReflow::Config).to receive(:get) { "true" }
                end

                it "doesn't push local squash merged base branch to remote repo" do
                  expect { subject }.to_not have_run_command("git push origin master")
                end

                it "doesn't delete the remote feature branch" do
                  expect { subject }.to_not have_run_command("git push origin :new-feature")
                end

                it "doesn't delete the local feature branch" do
                  expect { subject }.to_not have_run_command("git branch -D new-feature")
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

              it "doesn't update the remote repo with the new squash merge" do
                expect { subject }.to_not have_run_command('git push origin master')
              end

              it "doesn't delete the feature branch on the remote repo" do
                expect { subject }.to_not have_run_command('git push origin :new-feature')
              end

              it "doesn't delete the local feature branch" do
                expect { subject }.to_not have_run_command('git branch -D new-feature')
              end

              it "doesn't provide instructions to undo the steps taken" do
                expect { subject }.to_not have_output("To reset and go back to your branch run \`git reset --hard origin/master && git checkout new-feature\`")
              end
            end

            context "and there were issues commiting the squash merge to the base branch" do
              before { stub_with_fallback(GitReflow, :run_command_with_label).with('git commit', {with_system: true}).and_return false }
              it "doesn't notifies user of issues commiting the squash merge of the feature branch" do
                expect { subject }.to_not have_said("There were problems commiting your feature... please check the errors above and try again.", :error)
              end
            end
          end

          context 'but there are 2 LGTMs and LGTM last comment' do
            let(:lgtm_comment_authors) { ['nhance', 'Simon'] }
            before do
              allow(existing_pull_request).to receive(:approvals).and_return(lgtm_comment_authors)
              allow(existing_pull_request).to receive(:reviewers_pending_response).and_return([])
              allow(existing_pull_request).to receive_message_chain(:last_comment, :match).and_return(true)
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
                allow(existing_pull_request).to receive(:reviewers).and_return(lgtm_comment_authors)
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
            allow(existing_pull_request).to receive(:approvals).and_return(['John', 'Simon'])
            allow(existing_pull_request).to receive(:reviewers_pending_response).and_return([])
            allow(existing_pull_request).to receive(:build).and_return(build_status)
          end

          it "notifies the user to get their code reviewed" do
            expect { subject }.to have_said "Pull Request successfully merged.", :success
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
end
