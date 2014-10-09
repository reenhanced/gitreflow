require 'spec_helper'

describe GitReflow do
  let(:github)           { Github.new basic_auth: "#{user}:#{password}" }
  let(:user)             { 'reenhanced' }
  let(:password)         { 'shazam' }
  let(:oauth_token_hash) { Hashie::Mash.new({ token: 'a1b2c3d4e5f6g7h8i9j0'}) }
  let(:repo)             { 'repo' }
  let(:base_branch)      { 'master' }
  let(:feature_branch)   { 'new-feature' }
  let(:enterprise_site)  { 'https://github.reenhanced.com' }
  let(:enterprise_api)   { 'https://github.reenhanced.com' }
  let(:hostname)         { 'hostname.local' }

  let(:github_authorizations) { Github::Client::Authorizations.new }
  let(:existing_pull_request) { Hashie::Mash.new(JSON.parse(fixture('pull_requests/pull_request.json').read)) }

  before do
    HighLine.any_instance.stub(:ask) do |terminal, question|
      values = {
        "Please enter your GitHub username: "                                                 => user,
        "Please enter your GitHub password (we do NOT store this): "                          => password,
        "Please enter your Enterprise site URL (e.g. https://github.company.com):"            => enterprise_site,
        "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):" => enterprise_api,
        "Would you like to open it in your browser?"                                          => 'n'
      }
     return_value = values[question]
     question = ""
     return_value
    end
  end

  context :setup do
    let(:setup_options) { {} }
    subject             { GitReflow.setup(setup_options) }

    before do
      github.stub(:oauth).and_return(github_authorizations)
      github.stub_chain(:oauth, :all).and_return([])
      GitReflow.stub(:run).with('hostname', loud: false).and_return(hostname)
    end

    context "with valid GitHub credentials" do
      before do
        Github.stub(:new).and_return(github)
        github_authorizations.stub(:authenticated?).and_return(true)
        github.oauth.stub(:create).with({ scopes: ['repo'], note: "git-reflow (#{hostname})" }).and_return(oauth_token_hash)
      end

      it "notifies the user of successful setup" do
        expect { subject }.to have_output "\nYour GitHub account was successfully setup!"
      end

      it "creates a new GitHub oauth token" do
        github.oauth.should_receive(:create).and_return(oauth_token_hash)
        subject
      end

      it "creates git config keys for github connections" do
        expect { subject }.to have_run_commands_in_order [
          "git config --global --replace-all github.site \"#{github.site}\"",
          "git config --global --replace-all github.endpoint \"#{github.endpoint}\"" ,
          "git config --global --replace-all github.oauth-token \"#{oauth_token_hash[:token]}\""
        ]
      end

      context "exclusive to project" do
        let(:setup_options) {{ project_only: true }}
        it "creates _local_ git config keys for github connections" do
        expect { subject }.to have_run_commands_in_order [
            "git config --replace-all github.site \"#{github.site}\"",
            "git config --replace-all github.endpoint \"#{github.endpoint}\"" ,
            "git config --replace-all github.oauth-token \"#{oauth_token_hash[:token]}\""
          ]
        end
      end

      context "use GitHub enterprise account" do
        let(:setup_options) {{ enterprise: true }}
        it "creates git config keys for github connections" do
        expect { subject }.to have_run_commands_in_order [
            "git config --global --replace-all github.site \"#{enterprise_site}\"",
            "git config --global --replace-all github.endpoint \"#{enterprise_api}\"" ,
            "git config --global --replace-all github.oauth-token \"#{oauth_token_hash[:token]}\""
          ]
        end
      end

      context "oauth token already exists" do
        before { github.stub_chain(:oauth, :all).and_return [oauth_token_hash.merge(note: "git-reflow (#{hostname})")] }
        it "uses existing authorization token" do
          github.oauth.unstub(:create)
          github.oauth.should_not_receive(:create)
          expect{ subject }.to have_run_command_silently "git config --global --replace-all github.oauth-token \"#{oauth_token_hash[:token]}\""
        end
      end
    end

    context "with invalid GitHub credentials" do
      let(:unauthorized_error_response) {{
        response_headers: {'content-type' => 'application/json; charset=utf-8', status: 'Unauthorized'},
        method: 'GET',
        status: '401',
        body: { error: "GET https://api.github.com/authorizations: 401 Bad credentials" }
      }}

      before do
        Github.should_receive(:new).and_raise Github::Error::Unauthorized.new(unauthorized_error_response)
      end

      it "notifies user of invalid login details" do
        expect { subject }.to have_output "\nInvalid username or password"
      end
    end
  end

  context :status do
    subject { GitReflow.status(base_branch) }

    before do
      GitReflow.stub(:current_branch).and_return(feature_branch)
      GitReflow.stub(:destination_branch).and_return(base_branch)
    end

    context 'with no existing pull request' do
      before { GitReflow.stub(:find_pull_request).with(from: feature_branch, to: base_branch).and_return(nil) }
      it     { expect{ subject }.to have_output "\n[notice] No pull request exists for #{feature_branch} -> #{base_branch}" }
      it     { expect{ subject }.to have_output "[notice] Run 'git reflow review #{base_branch}' to start the review process" }
    end

    context 'with an existing pull request' do
      before { GitReflow.stub(:find_pull_request).with(from: feature_branch, to: base_branch).and_return(existing_pull_request) }

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
        :pull         => inputs
      })
    end

    subject { GitReflow.review inputs }

    it "fetches the latest changes to the destination branch" do
      GitReflow.should_receive(:fetch_destination).with(inputs['base'])
      GitReflow.should_receive(:find_pull_request).and_return(nil)
      github.stub_chain(:pull_requests, :create).and_return(existing_pull_request)
      subject
    end

    it "pushes the latest current branch to the origin repo" do
      GitReflow.should_receive(:push_current_branch)
      GitReflow.should_receive(:find_pull_request).and_return(nil)
      github.stub_chain(:pull_requests, :create).and_return(existing_pull_request)
      subject
    end

    context "pull request doesn't exist" do
      before { GitReflow.stub(:find_pull_request).and_return(nil) }

      it "successfully creates a pull request if I do not provide one" do
        existing_pull_request.stub(:title).and_return(inputs['title'])
        github.stub_chain(:pull_requests, :create).and_return(existing_pull_request)
        github.pull_requests.should_receive(:create).with(user, repo, inputs.except('state'))
        expect { subject }.to have_output "Successfully created pull request #1: #{inputs['title']}\nPull Request URL: https://github.com/#{user}/#{repo}/pulls/1\n"
      end
    end

    context "pull request exists" do
      let(:existing_pull_request) { Hashie::Mash.new({ html_url: "https://github.com/#{user}/#{repo}/pulls/1" }) }

      before do
        GitReflow.stub(:push_current_branch)
        github_error = Github::Error::UnprocessableEntity.new( eval(fixture('pull_requests/pull_request_exists_error.json').read) )
        github.pull_requests.stub(:create).with(user, repo, inputs.except('state')).and_raise(github_error)
        GitReflow.stub(:display_pull_request_summary).with(existing_pull_request)
        GitReflow.stub(:find_pull_request).with( from: branch, to: 'master').and_return(existing_pull_request)
      end

      subject { GitReflow.review inputs }

      it "displays a pull request summary for the existing pull request" do
        GitReflow.should_receive(:display_pull_request_summary).with(existing_pull_request)
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

    before do
      stub_github_with({
        :user         => user,
        :password     => password,
        :repo         => repo,
        :branch       => branch
      })
    end

    subject { GitReflow.deliver inputs }

    it "fetches the latest changes to the destination branch" do
      GitReflow.should_receive(:fetch_destination).with('master')
      GitReflow.stub(:find_pull_request)
      subject
    end

    it "looks for a pull request matching the feature branch and destination branch" do
      GitReflow.should_receive(:find_pull_request).with(from: branch, to: 'master')
      subject
    end

    context "and pull request exists for the feature branch to the destination branch" do
      before do
        GitReflow.stub(:find_pull_request).and_return(existing_pull_request)
        GitReflow.stub(:get_build_status).and_return(build_status)
        GitReflow.stub(:has_pull_request_comments?).and_return(true)
        GitReflow.stub(:find_authors_of_open_pull_request_comments).and_return([])
        GitReflow.stub(:comment_authors_for_pull_request).and_return(['codenamev'])
      end

      context 'and build status is not "success"' do
        let(:build_status) { Hashie::Mash.new({ state: 'failure', description: 'Build resulted in failed test(s)' }) }

        before do
          # just stubbing these in a locked state as the test is specific to this scenario
          GitReflow.stub(:find_authors_of_open_pull_request_comments).and_return([])
          GitReflow.stub(:has_pull_request_comments?).and_return(true)
        end

        it "halts delivery and notifies user of a failed build" do
          expect { subject }.to have_output "[#{ 'deliver halted'.colorize(:red) }] #{build_status.description}: #{build_status.target_url}"
        end
      end

      context 'and build status is nil' do
        let(:build_status) { nil }
        let(:inputs) {{ skip_lgtm: true }}

        before do
          # stubbing unrelated results so we can just test that it made it insdide the conditional block
          GitReflow.stub(:find_authors_of_open_pull_request_comments).and_return([])
          GitReflow.stub(:has_pull_request_comments?).and_return(true)
          GitReflow.stub(:comment_authors_for_pull_request).and_return([])
          GitReflow.stub(:update_destination).and_return(true)
          GitReflow.stub(:merge_feature_branch).and_return(true)
          GitReflow.stub(:append_to_squashed_commit_message).and_return(true)
        end

        it "ignores build status when not setup" do
          expect { subject }.to have_output "Merge complete!"
        end
      end

      context 'and build status is "success"' do
        let(:build_status) { Hashie::Mash.new({ state: 'success' }) }

        context 'and has comments' do
          before do
            GitReflow.stub(:has_pull_request_comments?).and_return(true)
            GitReflow.stub(:find_authors_of_open_pull_request_comments).and_return([])
          end

          context 'but there is a LGTM' do
            let(:lgtm_comment_authors) { ['nhance'] }
            before { stub_with_fallback(GitReflow, :comment_authors_for_pull_request).with(existing_pull_request, with: GitReflow::LGTM).and_return(lgtm_comment_authors) }

            it "includes the pull request body in the commit message" do
              squash_message = "#{existing_pull_request.body}\nCloses ##{existing_pull_request.number}\n\nLGTM given by: @nhance\n"
              GitReflow.should_receive(:append_to_squashed_commit_message).with(squash_message)
              subject
            end

            context "and the pull request has no body" do
              let(:first_commit_message) { "We'll do it live." }

              before do
                existing_pull_request[:body] = ''
                GitReflow.stub(:get_first_commit_message).and_return(first_commit_message)
                GitReflow.stub(:comment_authors_for_pull_request).and_return(lgtm_comment_authors)
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
              expect { subject }.to have_run_command('git commit')
              expect { subject }.to have_output 'Merge complete!'
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
                 return_value = values[question]
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
                 return_value = values[question]
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
            end

            context "and there were issues commiting the squash merge to the base branch" do
              before { stub_with_fallback(GitReflow, :run_command_with_label).with('git commit').and_return false }
              it "notifies user of issues commiting the squash merge of the feature branch" do
                expect { subject }.to have_output("There were problems commiting your feature... please check the errors above and try again.")
              end
            end

          end

          context 'but there are still unaddressed comments' do
            let(:open_comment_authors) { ['nhance', 'codenamev'] }
            before { GitReflow.stub(:find_authors_of_open_pull_request_comments).and_return(open_comment_authors) }
            it "notifies the user to get their code reviewed" do
              expect { subject }.to have_output "[deliver halted] You still need a LGTM from: #{open_comment_authors.join(', ')}"
            end
          end
        end

        context 'but has no comments' do
          before do
            GitReflow.stub(:has_pull_request_comments?).and_return(false)
            GitReflow.stub(:find_authors_of_open_pull_request_comments).and_return([])
          end

          it "notifies the user to get their code reviewed" do
            expect { subject }.to have_output "[deliver halted] Your code has not been reviewed yet."
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
      before { GitReflow.stub(:find_pull_request).and_return(nil) }

      it "notifies the user of a missing pull request" do
        expect { subject }.to have_output "Error: No pull request exists for #{user}:#{branch}\nPlease submit your branch for review first with \`git reflow review\`"
      end
    end
  end
end
