require 'spec_helper'

describe GitReflow::GitServer::PullRequest do
  let(:pull_request) { Fixture.new('pull_requests/external_pull_request.json').to_json_hashie }
  let(:github)      { stub_github_with({ user: 'reenhanced', repo: 'repo', pull: pull_request }) }
  let!(:github_api) { github.connection }
  let(:git_server)  { GitReflow::GitServer::GitHub.new {} }

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
      GitReflow.git_server.stub(:find_open_pull_request).with({from: 'new-feature', to: 'master'}).and_return(pull_request)
      
      # stubs approvals and last_comment conditions to default to true
      pull_request.stub(:approvals).and_return(["Simon", "John"])
      pull_request.stub_chain(:last_comment, :match).and_return(true)
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

      specify { subject.rejection_message.should eq(": ") }
    end

    context "Testing Minimum Approvals Failure" do
      before do
        allow(subject).to receive(:build_status).and_return('success')
        allow(subject).to receive(:approval_minimums_reached?).and_return(false)
        allow(GitReflow::GitServer::PullRequest).to receive(:minimum_approvals).and_return("2")
      end
      specify { subject.rejection_message.should eq("You need approval from at least 2 users!") }
    end

    context "Testing Minimum Approvals Reached" do
      before do
        allow(subject).to receive(:build_status).and_return(nil)
        allow(subject).to receive(:all_comments_addressed?).and_return(false)
        allow(subject).to receive(:last_comment).and_return("Hello")
      end
      specify { subject.rejection_message.should eq("The last comment is holding up approval:\nHello") }
    end

    context "Testing All Comments Addressed" do
      before do
        allow(subject).to receive(:build_status).and_return('success')
        allow(subject).to receive(:all_comments_addressed?).and_return(false)
        allow(subject).to receive(:last_comment).and_return("Hello")
      end
      specify { subject.rejection_message.should eq("The last comment is holding up approval:\nHello") }
    end

    context "Testing All Comments Addressed" do
      before do
        allow(subject).to receive(:reviewers_pending_response).and_return(['Simon'])
        allow(subject).to receive(:build?).and_return('success')
        allow(subject).to receive(:all_comments_addressed?).and_return(true)
        allow(subject).to receive(:approval_minimums_reached?).and_return(true)
      end
      specify { subject.rejection_message.should eq( "You still need a LGTM from: Simon") }
    end

    context "Testing Last Case" do
      before do
        allow(subject).to receive(:reviewers_pending_response).and_return([])
        allow(subject).to receive(:build?).and_return('success')
        allow(subject).to receive(:all_comments_addressed?).and_return(true)
        allow(subject).to receive(:approval_minimums_reached?).and_return(true)
      end
      specify { subject.rejection_message.should eq("Your code has not been reviewed yet.") }
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
      specify { subject.approval_minimums_reached?.should eq(true) }
    end

    context "Testing a Success Case" do
      before do
        allow(subject).to receive(:minimum_approvals).and_return('2')
        allow(subject).to receive(:approvals).and_return(['Simon', 'John'])
      end
      specify { subject.approval_minimums_reached?.should eq(true) }
    end

    context "Testing Case with no minimum_approval" do
      before do
        allow(subject).to receive(:minimum_approvals).and_return('')
        allow(subject).to receive(:approvals).and_return([])
      end
      specify { subject.approval_minimums_reached?.should eq(true) }
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
        GitReflow.git_server.stub(:find_open_pull_request).with({from: 'new-external-feature', to: 'master'}).and_return(pull_request)
      end

      it "displays relavent information about the pull request" do
        expect{ subject }.to have_output("branches: new-external-feature -> reenhanced:master")
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
        GitReflow.git_server.stub(:find_open_pull_request).with({from: 'new-external-feature', to: 'master'}).and_return(pull_request)
      end

      it "displays relavent information about the pull request" do
        expect{ subject }.to have_output("branches: new-external-feature -> reenhanced:master")
        expect{ subject }.to have_output("number: #{pull_request.number}")
        expect{ subject }.to have_output("url: #{pull_request.html_url}")
        expect{ subject }.to have_output("reviewed by: #{"tito".colorize(:green)}, #{"ringo".colorize(:green)}, #{"Simon".colorize(:green)}, #{"Peter".colorize(:green)}, #{"Johnny".colorize(:green)}, #{"Jacob".colorize(:green)}")
        expect{ subject }.to have_output("Last comment: \"LOOKS GOOD TO ME\"")
      end
    end
  end
end
