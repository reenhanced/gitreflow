require 'spec_helper'

describe GitReflow::GitServer::PullRequest do
  let(:pull_request) { Fixture.new('pull_requests/external_pull_request.json').to_json_hashie }
  let(:github)      { stub_github_with({ user: 'reenhanced', repo: 'repo', pull: pull_request }) }
  let!(:github_api) { github.connection }
  let(:git_server)  { GitReflow::GitServer::GitHub.new {} }
  let(:user)             { 'reenhanced' }
  let(:password)         { 'shazam' }
  let(:enterprise_site)  { 'https://github.reenhanced.com' }
  let(:enterprise_api)   { 'https://github.reenhanced.com' }

  describe "#good_to_merge?(options)" do
    subject            { GitReflow::GitServer::GitHub::PullRequest.new(pull_request) }

    before do
      FakeGitHub.new(
        repo_owner:   'reenhanced',
        repo_name:    'repo',
        pull_request: {
          number:   pull_request.number,
          owner:    pull_request.head.user.login,
          comments: [{author: 'tito', body: 'lgtm'}, {author: 'ringo', body: ':+1:'}]
        })
      # setup initial valid state
      allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:build).and_return(Struct.new(:state, :description, :url).new)
      allow(GitReflow.git_server).to receive(:find_open_pull_request).with({from: 'new-feature', to: 'master'}).and_return(pull_request)
      
      # stubs approvals and last_comment conditions to default to true
      allow(pull_request).to receive(:approvals).and_return(["Simon", "John"])
      allow(pull_request).to receive_message_chain(:last_comment, :match).and_return(true)
      allow(GitReflow::GitServer::PullRequest).to receive(:minimum_approvals).and_return("2")
      allow(GitReflow::GitServer::PullRequest).to receive(:approval_regex).and_return(/(?i-mx:lgtm|looks good to me|:\+1:|:thumbsup:|:shipit:)/)

    end
    context "with no status" do
      specify { expect(subject.good_to_merge?).to eq(true) }
    end

    context "with build status" do
      context "of 'success'" do
        before  { allow(subject).to receive(:build_status).and_return('success') }
        specify { expect(subject.good_to_merge?).to eq(true) }
      end

      context "NOT of 'success'" do
        before { allow(subject).to receive(:build_status).and_return('failure') }
        specify { expect(subject.good_to_merge?).to eq(false) }
      end
    end

    # Need at least 1 comment for you to merge
    context "with no comments" do
      before {
        allow(subject).to receive(:has_comments?).and_return(false)
        allow(subject).to receive(:build_status).and_return('success')
        allow(subject).to receive(:approvals).and_return(["Simon", "John"])
      }
      specify { expect(subject.good_to_merge?).to eq(true) }
      context "and no approvals" do
        before { allow(subject).to receive(:approvals).and_return([]) }
        specify { expect(subject.good_to_merge?).to eq(false) }
      end
    end

    context "with 1 approval" do
      before do
        allow(subject).to receive(:reviewers).and_return(['bob'])
        allow(subject).to receive(:approvals).and_return(['joe'])
      end
      specify { expect(subject.good_to_merge?).to eq(false) }
    end

    context "with 2 approvals" do
      before do
        allow(subject).to receive(:reviewers).and_return(['bob'])
        allow(subject).to receive(:approvals).and_return(['joe', 'bob'])
        allow(subject).to receive(:last_comment).and_return('hi')
        allow(subject).to receive(:build_status).and_return('success')
      end
      specify { expect(subject.good_to_merge?).to eq(false) }
    end

    context "with 2 approvals and last comment LGTM" do
      before do
        allow(subject).to receive(:reviewers).and_return(['bob'])
        allow(subject).to receive(:approvals).and_return(['joe', 'bob'])
        allow(subject).to receive(:last_comment).and_return('LGTM')
      end
      specify { expect(subject.good_to_merge?).to eq(true) }
    end

    context "with comments" do
      before do
        allow(subject).to receive(:reviewers).and_return(['bob'])
        allow(subject).to receive(:approvals).and_return([])
      end
      specify { expect(subject.good_to_merge?).to eq(false) }
    end

    context "force merge?" do
      context "with pending comments" do
        before { allow(subject).to receive(:approvals).and_return([]) }
        specify { expect(subject.good_to_merge?(force: true)).to eq(true) }
      end

      context "with build failure" do
        before { allow(subject).to receive(:build_status).and_return('failure') }
        specify { expect(subject.good_to_merge?(force: true)).to eq(true) }
      end
    end
  end

  describe "#approved?" do
    subject            { GitReflow::GitServer::GitHub::PullRequest.new(pull_request) }

    context "no approvals and build success" do
      before do
        FakeGitHub.new(
        repo_owner:   'reenhanced',
        repo_name:    'repo',
          pull_request: {
            number: pull_request.number,
            owner: pull_request.head.user.login,
            comments: []
          })
        allow(GitReflow.git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :target_url).new())
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:minimum_approvals).and_return("0")
      end
      specify { expect(subject.approved?).to be_truthy }
    end

    context "all commenters must approve and minimum_approvals is nil" do
      before do
        FakeGitHub.new(
        repo_owner:   'reenhanced',
        repo_name:    'repo',
          pull_request: {
            number: pull_request.number,
            owner: pull_request.head.user.login,
            comments: []
          })
        allow(GitReflow.git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :target_url).new())
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:minimum_approvals).and_return(nil)
        allow(subject).to receive(:approvals).and_return(["Simon"])
        allow(subject).to receive(:has_comments?).and_return(true)
        allow(subject).to receive(:reviewers_pending_response).and_return([])
      end
      specify { expect(subject.approved?).to be_truthy }
    end

    context "all commenters must approve but we have no pending reviewers" do
      before do
        FakeGitHub.new(
          repo_owner:   'reenhanced',
          repo_name:    'repo',
          pull_request: {
            number: pull_request.number,
            owner: pull_request.head.user.login,
            comments: []
          })
        allow(GitReflow.git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :target_url).new())
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:minimum_approvals).and_return("")
        allow(subject).to receive(:has_comments?).and_return(true)
        allow(subject).to receive(:approvals).and_return(["Simon"])
        allow(subject).to receive(:reviewers_pending_response).and_return([])
      end
      specify { expect(subject.approved?).to be_truthy }
    end

    context "all commenters must approve but we have 1 pending reviewer" do
      before do
        FakeGitHub.new(
          repo_owner:   'reenhanced',
          repo_name:    'repo',
          pull_request: {
            number: pull_request.number,
            owner: pull_request.head.user.login,
            comments: []
          })
        allow(GitReflow.git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :target_url).new())
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:minimum_approvals).and_return("")
        allow(subject).to receive(:has_comments?).and_return(true)
        allow(subject).to receive(:approvals).and_return(["Simon"])
        allow(subject).to receive(:reviewers_pending_response).and_return(["Simon"])
      end
      specify { expect(subject.approved?).to be_falsy }
    end

    context "2 approvals required but we only have 1 approval" do
      before do
        FakeGitHub.new(
          repo_owner:   'reenhanced',
          repo_name:    'repo',
          pull_request: {
            number: pull_request.number,
            owner: pull_request.head.user.login,
            comments: []
          })
        allow(GitReflow.git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :target_url).new())
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:minimum_approvals).and_return("2")
        allow(subject).to receive(:approvals).and_return(["Simon"])
        allow(subject).to receive(:last_comment).and_return("LGTM")
      end
      specify { expect(subject.approved?).to be_falsy }
    end

    context "2 approvals required and we have 2 approvals but last comment is not approval" do
      before do
        FakeGitHub.new(
          repo_owner:   'reenhanced',
          repo_name:    'repo',
          pull_request: {
            number: pull_request.number,
            owner: pull_request.head.user.login,
            comments: []
          })
        allow(GitReflow.git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :target_url).new())
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:minimum_approvals).and_return("2")
        allow(subject).to receive(:approvals).and_return(["Simon", "Peter"])
        allow(subject).to receive(:last_comment).and_return("Boo")
      end
      specify { expect(subject.approved?).to be_falsy }
    end

    context "2 approvals required and we have 2 approvals and last comment is approval" do
      before do
        FakeGitHub.new(
          repo_owner:   'reenhanced',
          repo_name:    'repo',
          pull_request: {
            number: pull_request.number,
            owner: pull_request.head.user.login,
            comments: []
          })
        allow(GitReflow.git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :target_url).new())
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:minimum_approvals).and_return("2")
        allow(subject).to receive(:approvals).and_return(["Simon", "Peter"])
        allow(subject).to receive(:last_comment).and_return("LGTM")
      end
      specify { expect(subject.approved?).to be_truthy }
    end
  end

  describe "#rejection_message" do
    subject            { GitReflow::GitServer::GitHub::PullRequest.new(pull_request) }

    before do
      allow(GitReflow.git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :target_url).new())
    end

    context "Testing a Failure Build Status" do
      before do
        allow(subject).to receive(:build_status).and_return('failure')
      end

      specify { expect(subject.rejection_message).to eq(": ") }
    end

    context "Testing Minimum Approvals Failure" do
      before do
        allow(subject).to receive(:build_status).and_return('success')
        allow(subject).to receive(:approval_minimums_reached?).and_return(false)
        allow(GitReflow::GitServer::PullRequest).to receive(:minimum_approvals).and_return("2")
      end
      specify { expect(subject.rejection_message).to eq("You need approval from at least 2 users!") }
    end

    context "Testing Minimum Approvals Reached" do
      before do
        allow(subject).to receive(:build_status).and_return(nil)
        allow(subject).to receive(:all_comments_addressed?).and_return(false)
        allow(subject).to receive(:last_comment).and_return("Hello")
      end
      specify { expect(subject.rejection_message).to eq("The last comment is holding up approval:\nHello") }
    end

    context "Testing All Comments Addressed" do
      before do
        allow(subject).to receive(:build_status).and_return('success')
        allow(subject).to receive(:all_comments_addressed?).and_return(false)
        allow(subject).to receive(:last_comment).and_return("Hello")
      end
      specify { expect(subject.rejection_message).to eq("The last comment is holding up approval:\nHello") }
    end

    context "Testing All Comments Addressed" do
      before do
        allow(subject).to receive(:reviewers_pending_response).and_return(['Simon'])
        allow(subject).to receive(:build?).and_return('success')
        allow(subject).to receive(:all_comments_addressed?).and_return(true)
        allow(subject).to receive(:approval_minimums_reached?).and_return(true)
      end
      specify { expect(subject.rejection_message).to eq( "You still need a LGTM from: Simon") }
    end

    context "Testing Last Case" do
      before do
        allow(subject).to receive(:reviewers_pending_response).and_return([])
        allow(subject).to receive(:build?).and_return('success')
        allow(subject).to receive(:all_comments_addressed?).and_return(true)
        allow(subject).to receive(:approval_minimums_reached?).and_return(true)
      end
      specify { expect(subject.rejection_message).to eq("Your code has not been reviewed yet.") }
    end
  end

  describe "#all_comments_addressed" do
    subject            { GitReflow::GitServer::GitHub::PullRequest.new(pull_request) }

    before do
      allow(GitReflow.git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :target_url).new())
    end

    context "Testing a Failure Case" do
      before do
        allow(subject).to receive(:minimum_approvals).and_return('2')
        allow(subject).to receive(:approvals).and_return(['Simon'])
      end
      specify { expect(subject.approval_minimums_reached?).to eq(true) }
    end

    context "Testing a Success Case" do
      before do
        allow(subject).to receive(:minimum_approvals).and_return('2')
        allow(subject).to receive(:approvals).and_return(['Simon', 'John'])
      end
      specify { expect(subject.approval_minimums_reached?).to eq(true) }
    end

    context "Testing Case with no minimum_approval" do
      before do
        allow(subject).to receive(:minimum_approvals).and_return('')
        allow(subject).to receive(:approvals).and_return([])
      end
      specify { expect(subject.approval_minimums_reached?).to eq(true) }
    end
  end

  describe "#display_pull_request_summary" do
    subject            { GitReflow::GitServer::GitHub::PullRequest.new(pull_request).display_pull_request_summary }

    context "Testing Pull Request Properties" do
      before do
        FakeGitHub.new(
          repo_owner:   'reenhanced',
          repo_name:    'repo',
          pull_request: {
            number:   pull_request.number,
            owner:    pull_request.head.user.login,
            comments: [{author: 'tito', body: 'lgtm'}, {author: 'ringo', body: ':+1:'}]
          })
        allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:build).and_return(Struct.new(:state, :description, :url).new)
        allow(GitReflow.git_server).to receive(:find_open_pull_request).with({from: 'new-external-feature', to: 'master'}).and_return(pull_request)
      end

      it "displays relavent information about the pull request" do
        expect{ subject }.to have_output("branches: new-external-feature -> master")
        expect{ subject }.to have_output("number: #{pull_request.number}")
        expect{ subject }.to have_output("url: #{pull_request.html_url}")
        expect{ subject }.to have_output("reviewed by: #{"tito".colorize(:green)}, #{"ringo".colorize(:green)}")
        expect{ subject }.to have_output("Last comment: \":+1:\"")
      end
    end

    context "Testing Different LGTM Regex Expressions " do
      before do
        FakeGitHub.new(
          repo_owner:   'reenhanced',
          repo_name:    'repo',
          pull_request: {
            number:   pull_request.number,
            owner:    pull_request.head.user.login,
            comments: [
              {author: 'tito', body: 'lgtm'}, 
              {author: 'ringo', body: ':+1:'}, 
              {author: 'Simon', body: ':shipit:'}, 
              {author: 'Peter', body: 'looks good to me'},
              {author: 'Johnny', body: 'LgTm'},
              {author: 'Jacob', body: 'LOOKS GOOD TO ME'}
            ]
          })
        allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:build).and_return(Struct.new(:state, :description, :url).new)
        allow(GitReflow.git_server).to receive(:find_open_pull_request).with({from: 'new-external-feature', to: 'master'}).and_return(pull_request)
      end

      it "displays relavent information about the pull request" do
        expect{ subject }.to have_output("branches: new-external-feature -> master")
        expect{ subject }.to have_output("number: #{pull_request.number}")
        expect{ subject }.to have_output("url: #{pull_request.html_url}")
        expect{ subject }.to have_output("reviewed by: #{"tito".colorize(:green)}, #{"ringo".colorize(:green)}, #{"Simon".colorize(:green)}, #{"Peter".colorize(:green)}, #{"Johnny".colorize(:green)}, #{"Jacob".colorize(:green)}")
        expect{ subject }.to have_output("Last comment: \"LOOKS GOOD TO ME\"")
      end
    end
  end

  context ".merge!" do
    subject            { GitReflow::GitServer::GitHub::PullRequest.new(pull_request) }

    let(:inputs) {
      { 
        :base => "base_branch",
        :title => "title",
        :message => "message"
      }
    }

    let(:lgtm_comment_authors) {
      ["simonzhu24", "reenhanced"]
    }

    let(:merge_response) { { :message => "Failure_Message" } }

    context "finds pull request but merge response fails" do
      before do
        allow(GitReflow).to receive(:git_server).and_return(git_server)
        allow(git_server).to receive(:connection).and_return(github)
        allow(git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :target_url).new())
        allow(GitReflow::GitServer::GitHub).to receive_message_chain(:connection, :pull_requests, :merge).and_return(merge_response)
        allow(merge_response).to receive(:success?).and_return(false)
        allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:approvals).and_return(lgtm_comment_authors)
        allow(subject).to receive(:deliver?).and_return(true)
        allow(merge_response).to receive(:to_s).and_return("Merge failed")
      end

      it "throws an error" do
        expect { subject.merge! inputs }.to have_said "Merge failed", :deliver_halted
        expect { subject.merge! inputs }.to have_said "There were problems commiting your feature... please check the errors above and try again.", :error
      end
    end
  end

  context ".commit_message_for_merge" do
    subject            { GitReflow::GitServer::GitHub::PullRequest.new(pull_request) }

    let(:lgtm_comment_authors) {
      ["simonzhu24", "reenhanced"]
    }

    let(:output) { lgtm_comment_authors.join(', @') }

    context "checks commit message generated is correct" do
      before do
        allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:build).and_return(Struct.new(:state, :description, :url).new)
        allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:description).and_return("Description")
        allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:number).and_return(1)
        allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:approvals).and_return(lgtm_comment_authors)
      end

      it "throws an exception without message" do
        expect(subject.commit_message_for_merge).to eq("Description\nMerges #1\n\nLGTM given by: @simonzhu24, @reenhanced\n\n")
      end
    end
  end

  context :cleanup_feature_branch? do
    subject { GitReflow::GitServer::GitHub::PullRequest.new(pull_request).cleanup_feature_branch? }

    before do
      allow(GitReflow::Config).to receive(:get).with("reflow.always-cleanup").and_return("false")
      allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:build).and_return(Struct.new(:state, :description, :url).new)
      FakeGitHub.new(
        repo_owner:   'reenhanced',
        repo_name:    'repo',
        pull_request: {
          number:   pull_request.number,
          owner:    pull_request.head.user.login,
          comments: [{author: 'tito', body: 'lgtm'}, {author: 'ringo', body: ':+1:'}]
        })
    end

    context "doesn't cleanup feature branch" do
      before do
        allow_any_instance_of(HighLine).to receive(:ask) do |terminal, question|
          values = {
            "Please enter your GitHub username: "                                                      => user,
            "Please enter your GitHub password (we do NOT store this): "                               => password,
            "Please enter your Enterprise site URL (e.g. https://github.company.com):"                 => enterprise_site,
            "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):"      => enterprise_api,
            "Would you like to push this branch to your remote repo and cleanup your feature branch? " => 'no',
            "Would you like to open it in your browser?"                                               => 'n',
            "This is the current status of your Pull Request. Are you sure you want to deliver? "      => 'n', 
            "Please enter your delivery commit title: (leaving blank will use default)"                => 'title',
            "Please enter your delivery commit message: (leaving blank will use default)"              => 'message'
          }
         return_value = values[question] || values[terminal]
         question = ""
         return_value
        end
      end

      it "doesn't cleans up feature branch" do
        expect(subject).to be_falsy
      end
    end

    context "does cleanup feature branch" do
      before do
        stub_command_line_inputs({
            "Please enter your GitHub username: "                                                      => user,
            "Please enter your GitHub password (we do NOT store this): "                               => password,
            "Please enter your Enterprise site URL (e.g. https://github.company.com):"                 => enterprise_site,
            "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):"      => enterprise_api,
            "Would you like to push this branch to your remote repo and cleanup your feature branch? " => 'yes',
            "This is the current status of your Pull Request. Are you sure you want to deliver? "      => 'n', 
            "Please enter your delivery commit title: (leaving blank will use default)"                => 'title',
            "Please enter your delivery commit message: (leaving blank will use default)"              => 'message'
        })
      end

      it "cleans up feature branch" do
        expect(subject).to be_truthy
      end
    end
  end

  context :deliver? do
    subject { GitReflow::GitServer::GitHub::PullRequest.new(pull_request).deliver? }

    before do
      allow(GitReflow::Config).to receive(:get).with("reflow.always-deliver").and_return("false")
      allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:build).and_return(Struct.new(:state, :description, :url).new)
      FakeGitHub.new(
        repo_owner:   'reenhanced',
        repo_name:    'repo',
        pull_request: {
          number:   pull_request.number,
          owner:    pull_request.head.user.login,
          comments: [{author: 'tito', body: 'lgtm'}, {author: 'ringo', body: ':+1:'}]
        })
    end

    context "doesn't deliver feature branch" do
      before do
        allow_any_instance_of(HighLine).to receive(:ask) do |terminal, question|
          values = {
            "Please enter your GitHub username: "                                                      => user,
            "Please enter your GitHub password (we do NOT store this): "                               => password,
            "Please enter your Enterprise site URL (e.g. https://github.company.com):"                 => enterprise_site,
            "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):"      => enterprise_api,
            "Would you like to push this branch to your remote repo and cleanup your feature branch? " => 'no',
            "Would you like to open it in your browser?"                                               => 'n',
            "This is the current status of your Pull Request. Are you sure you want to deliver? "      => 'n', 
            "Please enter your delivery commit title: (leaving blank will use default)"                => 'title',
            "Please enter your delivery commit message: (leaving blank will use default)"              => 'message'
          }
         return_value = values[question] || values[terminal]
         question = ""
         return_value
        end
      end

      it "doesn't deliver feature branch" do
        expect(subject).to be_falsy
      end
    end

    context "does deliver feature branch" do
      before do
        allow_any_instance_of(HighLine).to receive(:ask) do |terminal, question|
          values = {
            "Please enter your GitHub username: "                                                      => user,
            "Please enter your GitHub password (we do NOT store this): "                               => password,
            "Please enter your Enterprise site URL (e.g. https://github.company.com):"                 => enterprise_site,
            "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):"      => enterprise_api,
            "Would you like to push this branch to your remote repo and cleanup your feature branch? " => 'no',
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

      it "does deliver feature branch" do
        expect(subject).to be_truthy
      end
    end
  end
end
