require 'spec_helper'

class MockPullRequest < GitReflow::GitServer::PullRequest
  DESCRIPTION         = "Bingo! Unity."
  HTML_URL            = "https://github.com/reenhanced/gitreflow/pulls/0"
  FEATURE_BRANCH_NAME = "feature_branch"
  BASE_BRANCH_NAME    = "base"
  NUMBER              = 0

  def initialize(attributes)
    self.description         = attributes.description || DESCRIPTION
    self.html_url            = attributes.html_url || HTML_URL
    self.feature_branch_name = attributes.feature_branch_name || FEATURE_BRANCH_NAME
    self.base_branch_name    = attributes.base_branch_name || BASE_BRANCH_NAME
    self.build               = Build.new
    self.number              = attributes.number || NUMBER
    self.source_object       = attributes
  end
end

describe GitReflow::GitServer::PullRequest do
  let(:pull_request) { Fixture.new('pull_requests/external_pull_request.json').to_json_hashie }
  let(:github)      { stub_github_with({ user: 'reenhanced', repo: 'repo', pull: pull_request }) }
  let!(:github_api) { github.connection }
  let(:git_server)  { GitReflow::GitServer::GitHub.new {} }
  let(:user)             { 'reenhanced' }
  let(:password)         { 'shazam' }
  let(:enterprise_site)  { 'https://github.reenhanced.com' }
  let(:enterprise_api)   { 'https://github.reenhanced.com' }

  describe ".minimum_approvals" do
    before { allow(GitReflow::Config).to receive(:get).with('constants.minimumApprovals').and_return('2') }
    it     { should eql '2' }
  end

  describe ".approval_regex" do
    before { allow(GitReflow::Config).to receive(:get).with('constants.minimumApprovals').and_return('2') }
    it     { should eql '2' }

    context "with custom approval regex set" do
      before { allow(GitReflow::Config).to receive(:get).with('constants.approvalRegex').and_return('/dude/') }
      it     { should eql Regex.new('/dude/') }
    end
  end

  %w{commit_author comments last_comment reviewers approvals}.each do |method_name|
    describe "##{method_name}" do
      specify { expect( GitReflow::GitServer::PullRequest.new({}).send(method_name.to_sym) ).to raise_error("PullRequest##{method_name} method must be implemented") }
    end
  end

  describe "#good_to_merge?(options)" do
    subject { MockPullRequest.new(pull_request) }

    context "with no status" do
      specify { expect(subject.good_to_merge?).to eq(true) }
    end

    context "with build status" do
      context "of 'success'" do
        before  { allow(subject).to receive(:build_status).and_return('success') }

        context "and approved" do
          before { allow(subject).to receive(:approved?).and_return(true) }
          specify { expect(subject.good_to_merge?).to eq(true) }
        end

        context "but not approved" do
          before { allow(subject).to receive(:approved?).and_return(false) }
          specify { expect(subject.good_to_merge?).to eq(false) }
        end
      end

      context "NOT of 'success'" do
        before { allow(subject).to receive(:build_status).and_return('failure') }

        context "and approved" do
          before { allow(subject).to receive(:approved?).and_return(true) }
          specify { expect(subject.good_to_merge?).to eq(false) }
        end

        context "and not approved" do
          before { allow(subject).to receive(:approved?).and_return(false) }
          specify { expect(subject.good_to_merge?).to eq(false) }
        end
      end
    end

    context "force merge?" do
      context "with no successful build" do
        before { allow(subject).to receive(:build_status).and_return(nil) }
        specify { expect(subject.good_to_merge?(force: true)).to eq(true) }
      end

      context "with no approval" do
        before { allow(subject).to receive(:approved?).and_return(false) }
        specify { expect(subject.good_to_merge?(force: true)).to eq(true) }
      end

      context "with neither build success or approval" do
        before do
          allow(subject).to receive(:build_status).and_return(nil)
          allow(subject).to receive(:approved?).and_return(false)
        end
        specify { expect(subject.good_to_merge?(force: true)).to eq(true) }
      end
    end
  end

  describe "#approved?" do
    subject { MockPullRequest.new(pull_request) }

    context "no approvals required" do
      before do
        allow(subject).to receive(:has_comments?).and_return(false)
        allow(subject).to receive(:approvals?).and_return([])
      end
      specify { expect(subject.approved?).to be_truthy }
    end

    context "all commenters must approve" do
      before { allow(MockPullRequest).to receive(:minimum_approvals).and_return(nil) }

      context "and there are comments" do
        before { allow(subject).to receive(:comments).and_return(['Cool.', 'This is nice.']) }
        context "and there are no reviewers pending a resposne" do
          before { allow(subject).to receive(:reviewers_pending_response).and_return([]) }
          specify { expect(subject.approved?).to be_truthy }
        end
        context "but there are reviewers pending a resposne" do
          before { allow(subject).to receive(:reviewers_pending_response).and_return(['octocat']) }
          specify { expect(subject.approved?).to be_falsy }
        end
      end

      context "and there are no comments" do
        before { allow(subject).to receive(:comments).and_return(['Cool.', 'This is nice.']) }
        context "and there are approvals" do
          before { allow(subject).to receive(:approvals).and_return(['Sally']) }
          specify { expect(subject.approved?).to be_truthy }
        end
        context "and there are no approvals" do
          before { allow(subject).to receive(:approvals).and_return([]) }
          specify { expect(subject.approved?).to be_falsy }
        end
      end
    end

    context "custom minimum approval set" do
      before { allow(MockPullRequest).to receive(:minimum_approvals).and_return('2') }

      context "and approvals is greater than minimum" do
        before { allow(subject).to receive(:approvals).and_return(['Sally', 'Joey', 'Randy']) }
        it     { should be_truthy }
      end

      context "and approvals is equal to minimum" do
        before { allow(subject).to receive(:approvals).and_return(['Sally', 'Joey']) }
        it     { should be_truthy }
      end

      context "but approvals is less than minimum" do
        before { allow(subject).to receive(:approvals).and_return(['Sally']) }
        it     { should be_falsy }
      end
    end

  end

  describe "#rejection_message" do
    subject { MockPullRequest.new(pull_request) }

    context "and the build is not successful" do
      before do
        allow(subject).to receive(:build_status).and_return('failure')
        allow(subject).to receive(:build).and_return(MockPullRequest::Build.new(state: 'failure', description: 'no dice', url: 'https://example.com'))
        allow(subject).to receive(:reviewers).and_return([])
        allow(subject).to receive(:approvals).and_return([])
      end

      specify { expect(subject.rejection_message).to eq("no dice: https://example.com") }

      context "but it is blank" do
        before { allow(subject).to receive(:build_status).and_return(nil) }
        specify { expect(subject.rejection_message).to_not eq("no dice: https://example.com") }
      end
    end

    context "and the build is successful" do
      context "but approval minimums haven't been reached" do
        before do
          allow(subject).to receive(:approval_minimums_reached?).and_return(false)
          allow(MockPullRequest).to receive(:minimum_approvals).and_return('3')
        end
        specify { expect(subject.rejection_message).to eq("You need approval from at least 3 users!") }
      end

      context "and approval minimums have been reached" do
        before { allow(subject).to receive(:approval_minimums_reached?).and_return(true) }

        context "but all comments haven't been addressed" do
          before  do
            allow(subject).to receive(:all_comments_addressed?).and_return(false)
            allow(subject).to receive(:last_comment).and_return("nope")
          end
          specify { expect(subject.rejection_message).to eq("The last comment is holding up approval:\nnope") }
        end

        context "and all comments have been addressed" do
          before { allow(subject).to receive(:all_comments_addressed?).and_return(true) }

          context "but there are still pending reviews" do
            before  { allow(subject).to receive(:reviewers_pending_response).and_return(['sally', 'bog']) }
            specify { expect(subject.rejection_message).to eq("You still need a LGTM from: sally, bog") }
          end

          context "and there are no pending reviews" do
            before  { allow(subject).to receive(:reviewers_pending_response).and_return([]) }
            specify { expect(subject.rejection_message).to eq("Your code has not been reviewed yet.") }
          end
        end
      end
    end
  end

  describe "#approval_minimums_reached?" do
    subject { MockPullRequest.new(pull_request) }

    before { allow(subject).to receive(:approvals).and_return(['sally', 'bog']) }

    context "minimum approvals not set" do
      before  { allow(MockPullRequest).to receive(:minimum_approvals).and_return('') }
      specify { expect(subject.approval_minimums_reached?).to eql true }
    end

    context "minimum approvals not met" do
      before  { allow(MockPullRequest).to receive(:minimum_approvals).and_return('3') }
      specify { expect(subject.approval_minimums_reached?).to eql false }
    end

    context "minimum approvals met" do
      before  { allow(MockPullRequest).to receive(:minimum_approvals).and_return('2') }
      specify { expect(subject.approval_minimums_reached?).to eql true }
    end
  end

  describe "#all_comments_addressed" do
    subject { MockPullRequest.new(pull_request) }
    before  { allow(subject).to receive(:approvals).and_return(['sally', 'bog']) }

    context "minimum approvals not set" do
      before  do
        allow(MockPullRequest).to receive(:minimum_approvals).and_return('')
        allow(subject).to receive(:last_comment).and_return('nope')
      end
      specify { expect(subject.all_comments_addressed?).to eql true }
    end

    context "minimum approvals set" do
      before { allow(MockPullRequest).to receive(:minimum_approvals).and_return('2') }
      context "last comment approved" do
        before  { allow(subject).to receive(:last_comment).and_return('lgtm') }
        specify { expect(subject.all_comments_addressed?).to eql true }
      end

      context "last comment not approved" do
        before  { allow(subject).to receive(:last_comment).and_return('nope') }
        specify { expect(subject.all_comments_addressed?).to eql false }
      end
    end
  end

  describe "#display_pull_request_summary" do
    let(:pr) { MockPullRequest.new(pull_request) }
    subject  { pr.display_pull_request_summary }

    before do
      allow(pr).to receive(:reviewers).and_return([])
      allow(pr).to receive(:approvals).and_return([])
      allow(pr).to receive(:reviewers_pending_response).and_return([])
    end

    it "displays relavent information about the pull request" do
      expect{ subject }.to have_output("branches: #{pr.feature_branch_name} -> #{pr.base_branch_name}")
      expect{ subject }.to have_output("number: #{pr.number}")
      expect{ subject }.to have_output("url: #{pr.html_url}")
      expect{ subject }.to have_said("No one has reviewed your pull request.\n", :notice)
    end

    context "with build status" do
      let(:build) { MockPullRequest::Build.new(state: "failure", description: "no dice", url: "https://example.com") }
      before      { allow(pr).to receive(:build).and_return(build) }
      specify     { expect{ subject }.to have_said("Your build status is not successful: #{build.url}.\n", :notice) }
      context "and build status is 'success'" do
        before  { allow(build).to receive(:state).and_return('success') }
        specify { expect{ subject }.to_not have_output("Your build status is not successful") }
      end
    end

    context "with reviewers" do
      before do
        allow(pr).to receive(:reviewers).and_return(['tito', 'ringo'])
        allow(pr).to receive(:last_comment).and_return('nope')
      end

      specify { expect{ subject }.to have_output("reviewed by: #{"tito".colorize(:red)}, #{"ringo".colorize(:red)}") }
      specify { expect{ subject }.to have_output("Last comment: nope") }

      context "and approvals" do
        before { allow(pr).to receive(:approvals).and_return(['tito']) }
        specify { expect{ subject }.to have_output  'tito'.colorize(:green) }
        specify { expect{ subject }.to have_output  'ringo'.colorize(:red) }
      end

      context "and pending approvals" do
        before  { allow(pr).to receive(:reviewers_pending_response).and_return(['tito', 'ringo']) }
        specify { expect{ subject }.to_not have_output "You still need a LGTM from: tito, ringo" }
      end

      context "and no pending approvals" do
        before  { allow(pr).to receive(:reviewers_pending_response).and_return([]) }
        specify { expect{ subject }.to_not have_output "You still need a LGTM from" }
      end
    end
  end

  context "#merge!" do
    let(:pr) { MockPullRequest.new(pull_request) }
    let(:commit_message_for_merge) { "This changes everything!" }

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

    subject { pr.merge! inputs }

    before do
      allow(GitReflow).to receive(:append_to_squashed_commit_message)
      allow(pr).to receive(:commit_message_for_merge).and_return(commit_message_for_merge)
    end

    context "and can deliver" do
      before { allow(pr).to receive(:deliver?).and_return(true) }

      specify { expect{ subject }.to have_said "Merging pull request ##{pr.number}: '#{pr.title}', from '#{pr.feature_branch_name}' into '#{pr.base_branch_name}'", :notice }

      it "updates both feature and destination branch and squash-merges feature into base branch" do
        expect(GitReflow).to receive(:update_current_branch)
        expect(GitReflow).to receive(:fetch_destination).with(pr.base_branch_name)
        expect(GitReflow).to receive(:append_to_squashed_commit_message).with(pr.commit_message_for_merge)
        expect { subject }.to have_run_commands_in_order [
          "git checkout #{pr.base_branch_name}",
          "git pull origin #{pr.base_branch_name}",
          "git merge --squash #{pr.feature_branch_name}"
        ]
      end

      context "and successfully commits merge" do
        specify { expect{ subject }.to have_said "Pull request ##{pr.number} successfully merged.", :success }

        context "and cleaning up feature branch" do
          before { allow(pr).to receive(:cleanup_feature_branch?).and_return(true) }
          specify { expect{ subject }.to have_said "Nice job buddy." }
          it "pushes the base branch and removes the feature branch locally and remotely" do
            expect { subject }.to have_run_commands_in_order [
              "git push origin #{pr.base_branch_name}",
              "git push origin :#{pr.feature_branch_name}",
              "git branch -D #{pr.feature_branch_name}"
            ]
          end
        end

        context "but not cleaning up feature branch" do
          before { allow(pr).to receive(:cleanup_feature_branch?).and_return(false) }
          specify { expect{ subject }.to_not have_run_command "git push origin #{pr.base_branch_name}" }
          specify { expect{ subject }.to_not have_run_command "git push origin :#{pr.feature_branch_name}" }
          specify { expect{ subject }.to_not have_run_command "git branch -D #{pr.feature_branch_name}" }
          specify { expect{ subject }.to have_said "Cleanup halted.  Local changes were not pushed to remote repo.", :deliver_halted }
          specify { expect{ subject }.to have_said "To reset and go back to your branch run \`git reset --hard origin/#{pr.base_branch_name} && git checkout #{pr.feature_branch_name}\`" }
        end
      end

      context "but has an issue commiting the merge" do
        before do
          allow(GitReflow).to receive(:run_command_with_label)
          allow(GitReflow).to receive(:run_command_with_label).with('git commit', with_system: true).and_return(false)
        end
        specify { expect{ subject }.to have_said "There were problems commiting your feature... please check the errors above and try again.", :error }
      end
    end

    context "but cannot deliver" do
      before  { allow(pr).to receive(:deliver?).and_return(false) }
      specify { expect{ subject }.to have_said "Merge aborted", :deliver_halted }
    end
  end

  context "#commit_message_for_merge" do
    subject { MockPullRequest.new(pull_request) }

    let(:lgtm_comment_authors) {
      ["simonzhu24", "reenhanced"]
    }
    let(:output) { lgtm_comment_authors.join(', @') }
    let(:first_commit_message) { "Awesome commit here." }

    before { allow(GitReflow).to receive(:get_first_commit_message).and_return(first_commit_message) }

    context "with description" do
      pending "Adds description to message"
    end

    context "with approvals" do
      pending "Adds list of approvers"
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
