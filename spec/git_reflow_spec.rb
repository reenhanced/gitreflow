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
    HighLine.any_instance.stub(:ask) do |terminal, question|
      values = {
        "Please enter your GitHub username: "                                                      => user,
        "Please enter your GitHub password (we do NOT store this): "                               => password,
        "Please enter your Enterprise site URL (e.g. https://github.company.com):"                 => enterprise_site,
        "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):"      => enterprise_api,
        "Would you like to push this branch to your remote repo and cleanup your feature branch? " => 'yes',
        "Would you like to open it in your browser?"                                               => 'n'
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
      before { git_server.stub(:find_open_pull_request).with({from: feature_branch, to: base_branch}).and_return(nil) }
      it     { expect{ subject }.to have_output "\n[notice] No pull request exists for #{feature_branch} -> #{base_branch}" }
      it     { expect{ subject }.to have_output "[notice] Run 'git reflow review #{base_branch}' to start the review process" }
    end

    context 'with an existing pull request' do
      before do
        git_server.stub(:find_open_pull_request).with({from: feature_branch, to: base_branch}).and_return(existing_pull_request)
      end

      it 'displays a summary of the pull request and asks to open it in the browser' do
        GitReflow.should_receive(:display_pull_request_summary).with(existing_pull_request)
        GitReflow.should_receive(:ask_to_open_in_browser).with(existing_pull_request.html_url)
        subject
        $output.should include "Here's the status of your review:"
      end
    end
  end

  # Github Response specs thanks to:
  # https://github.com/peter-murach/github/blob/master/spec/github/pull_requests_spec.rb
  context :review do
    let(:branch) { 'new-feature' }
    let(:inputs) {
      {
       "title" => "Amazing new feature",
       "body" => "Please pull this in!",
       "head" => "reenhanced:new-feature",
       "base" => "master",
       "state" => "open"
      }
    }

    let(:github) do
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
      GitReflow.should_receive(:fetch_destination).with(inputs['base'])
      github.should_receive(:find_open_pull_request).and_return(nil)
      github.stub(:create_pull_request).and_return(existing_pull_request)
      subject
    end

    it "pushes the latest current branch to the origin repo" do
      GitReflow.should_receive(:push_current_branch)
      github.should_receive(:find_open_pull_request).and_return(nil)
      github.stub(:create_pull_request).and_return(existing_pull_request)
      subject
    end

    context "pull request doesn't exist" do
      before { github.stub(:find_open_pull_request).and_return(nil) }

      it "successfully creates a pull request if I do not provide one" do
        existing_pull_request.stub(:title).and_return(inputs['title'])
        github.should_receive(:create_pull_request).with(inputs.except('state').symbolize_keys).and_return(existing_pull_request)
        expect { subject }.to have_output "Successfully created pull request #1: #{inputs['title']}\nPull Request URL: https://github.com/#{user}/#{repo}/pulls/1\n"
      end
    end

    context "pull request exists" do
      before do
        GitReflow.stub(:push_current_branch)
        github_error = Github::Error::UnprocessableEntity.new( eval(Fixture.new('pull_requests/pull_request_exists_error.json').to_s) )
        github.stub(:create_pull_request).with(inputs.except('state')).and_raise(github_error)
        GitReflow.stub(:display_pull_request_summary)
      end

      subject { GitReflow.review inputs }

      it "displays a pull request summary for the existing pull request" do
        GitReflow.should_receive(:display_pull_request_summary)
        subject
      end

      it "asks to open the pull request in the browser" do
        GitReflow.should_receive(:ask_to_open_in_browser).with(existing_pull_request.html_url)
        subject
      end
    end
  end

  context :deliver do
    let(:branch)                { 'new-feature' }
    let(:inputs)                { {} }
    let!(:github) do
      stub_github_with({
        :user         => user,
        :password     => password,
        :repo         => repo,
        :branch       => branch,
        :pull         => existing_pull_request
      })
    end


    before do
      module Kernel
        def system(cmd)
          "call #{cmd}"
        end
      end
    end

    subject { GitReflow.deliver inputs }

    it "fetches the latest changes to the destination branch" do
      GitReflow.should_receive(:fetch_destination).with('master')
      subject
    end

    it "looks for a pull request matching the feature branch and destination branch" do
      github.should_receive(:find_open_pull_request).with(from: branch, to: 'master')
      subject
    end

    context "and pull request exists for the feature branch to the destination branch" do
      before do
        github.stub(:get_build_status).and_return(build_status)
        github.stub(:has_pull_request_comments?).and_return(true)
        github.stub(:comment_authors_for_pull_request).and_return(['codenamev'])
      end

      context 'and build status is not "success"' do
        let(:build_status) { Hashie::Mash.new({ state: 'failure', description: 'Build resulted in failed test(s)' }) }

        before do
          # just stubbing these in a locked state as the test is specific to this scenario
          GitReflow.stub(:has_pull_request_comments?).and_return(true)
        end

        it "halts delivery and notifies user of a failed build" do
          expect { subject }.to have_said "#{build_status.description}: #{build_status.target_url}", :deliver_halted
        end
      end

      context 'and build status is nil' do
        let(:build_status) { nil }
        let(:inputs) {{ skip_lgtm: true }}

        before do
          # stubbing unrelated results so we can just test that it made it insdide the conditional block
          GitReflow.stub(:has_pull_request_comments?).and_return(true)
          GitReflow.stub(:comment_authors_for_pull_request).and_return([])
          GitReflow.stub(:update_destination).and_return(true)
          GitReflow.stub(:merge_feature_branch).and_return(true)
          GitReflow.stub(:append_to_squashed_commit_message).and_return(true)
        end

        it "ignores build status when not setup" do
          expect { subject }.to have_said "Merge complete!", :success
        end
      end

      context 'and build status is "success"' do
        let(:build_status) { Hashie::Mash.new({ state: 'success' }) }

        context 'and has comments' do
          before do
            GitReflow.stub(:has_pull_request_comments?).and_return(true)
          end

          context 'but there is a LGTM' do
            let(:lgtm_comment_authors) { ['nhance'] }
            before do
              github.stub(:approvals).and_return(lgtm_comment_authors)
              github.stub(:reviewers_pending_response).and_return([])
            end

            it "includes the pull request body in the commit message" do
              squash_message = "#{existing_pull_request.body}\nCloses ##{existing_pull_request.number}\n\nLGTM given by: @nhance\n"
              GitReflow.should_receive(:append_to_squashed_commit_message).with(squash_message)
              subject
            end

            context "and the pull request has no body" do
              let(:first_commit_message) { "We'll do it live." }

              before do
                existing_pull_request.description = ''
                github.stub(:find_open_pull_request).and_return(existing_pull_request)
                GitReflow.stub(:get_first_commit_message).and_return(first_commit_message)
                github.stub(:comment_authors_for_pull_request).and_return(lgtm_comment_authors)
              end

              it "includes the first commit message for the new branch in the commit message of the merge" do
                squash_message = "#{first_commit_message}\nCloses ##{existing_pull_request.number}\n\nLGTM given by: @nhance\n"
                GitReflow.should_receive(:append_to_squashed_commit_message).with(squash_message)
                subject
              end
            end

            it "notifies user of the merge and performs it" do
              GitReflow.should_receive(:merge_feature_branch).with('new-feature', {
                destination_branch:  'master',
                pull_request_number: existing_pull_request.number,
                lgtm_authors:        ['nhance'],
                message:             existing_pull_request.body
              })

              expect { subject }.to have_output "Merging pull request ##{existing_pull_request.number}: '#{existing_pull_request.title}', from '#{existing_pull_request.head.label}' into '#{existing_pull_request.base.label}'"
            end

            it "updates the destination brnach" do
              GitReflow.should_receive(:update_destination).with('master')
              subject
            end

            it "commits the changes for the squash merge" do
              expect{ subject }.to have_said 'Merge complete!', :success
            end

            context "and cleaning up feature branch" do
              before do
                HighLine.any_instance.stub(:ask) do |terminal, question|
                  values = {
                    "Please enter your GitHub username: "                                                      => user,
                    "Please enter your GitHub password (we do NOT store this): "                               => password,
                    "Please enter your Enterprise site URL (e.g. https://github.company.com):"                 => enterprise_site,
                    "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):"      => enterprise_api,
                    "Would you like to push this branch to your remote repo and cleanup your feature branch? " => 'yes',
                    "Would you like to open it in your browser?"                                               => 'no'
                  }
                 return_value = values[question] || values[terminal]
                 question = ""
                 return_value
                end
              end

              it "pushes local squash merged base branch to remote repo" do
                expect { subject }.to have_run_command("git push origin master")
              end

              it "deletes the remote feature branch" do
                expect { subject }.to have_run_command("git push origin :new-feature")
              end

              it "deletes the local feature branch" do
                expect { subject }.to have_run_command("git branch -D new-feature")
              end
            end

            context "and not cleaning up feature branch" do
              before do
                HighLine.any_instance.stub(:ask) do |terminal, question|
                  values = {
                    "Please enter your GitHub username: "                                                      => user,
                    "Please enter your GitHub password (we do NOT store this): "                               => password,
                    "Please enter your Enterprise site URL (e.g. https://github.company.com):"                 => enterprise_site,
                    "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):"      => enterprise_api,
                    "Would you like to push this branch to your remote repo and cleanup your feature branch? " => 'no',
                    "Would you like to open it in your browser?"                                               => 'no'
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

              it "provides instructions to undo the steps taken" do
                expect { subject }.to have_output("To reset and go back to your branch run \`git reset --hard origin/master && git checkout new-feature\`")
              end
            end

            context "and there were issues commiting the squash merge to the base branch" do
              before { stub_with_fallback(GitReflow, :run_command_with_label).with('git commit', {with_system: true}).and_return false }
              it "notifies user of issues commiting the squash merge of the feature branch" do
                expect { subject }.to have_said("There were problems commiting your feature... please check the errors above and try again.", :error)
              end
            end

          end

          context 'but there are still unaddressed comments' do
            let(:open_comment_authors) { ['nhance', 'codenamev'] }
            before { github.stub(:reviewers_pending_response).and_return(open_comment_authors) }
            it "notifies the user to get their code reviewed" do
              expect { subject }.to have_said "You still need a LGTM from: #{open_comment_authors.join(', ')}", :deliver_halted
            end
          end
        end

        context 'but has no comments' do
          before do
            github.stub(:has_pull_request_comments?).and_return(false)
            github.stub(:approvals).and_return([])
            github.stub(:reviewers_pending_response).and_return([])
          end

          it "notifies the user to get their code reviewed" do
            expect { subject }.to have_said "Your code has not been reviewed yet.", :deliver_halted
          end
        end

        it "successfully finds a pull request for the current feature branch" do
          expect { subject }.to have_output "Merging pull request #1: 'new-feature', from 'new-feature' into 'master'"
        end

        it "checks out the destination branch and updates any remote changes" do
          GitReflow.should_receive(:update_destination)
          subject
        end

        it "merges and squashes the feature branch into the master branch" do
          GitReflow.should_receive(:merge_feature_branch)
          subject
        end
      end
    end

    context "and no pull request exists for the feature branch to the destination branch" do
      before { github.stub(:find_open_pull_request).and_return(nil) }

      it "notifies the user of a missing pull request" do
        expect { subject }.to have_said "No pull request exists for #{user}:#{branch}\nPlease submit your branch for review first with \`git reflow review\`", :deliver_halted
      end
    end
  end
end
