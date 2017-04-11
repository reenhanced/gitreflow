require 'spec_helper'

describe GitReflow::GitServer::GitHub::PullRequest do
  let(:user)                    { 'reenhanced' }
  let(:password)                { 'shazam' }
  let(:repo)                    { 'repo' }
  let(:oauth_token_hash)        { Hashie::Mash.new({ token: 'a1b2c3d4e5f6g7h8i9j0'}) }
  let(:hostname)                { 'hostname.local' }
  let(:github_site)             { 'https://github.com' }
  let(:github_api_endpoint)     { 'https://api.github.com' }
  let(:enterprise_site)         { 'https://github.gittyup.com' }
  let(:enterprise_api)          { 'https://github.gittyup.com/api/v3' }
  let(:github)                  { stub_github_with }
  let!(:github_api)             { github.connection }
  let(:existing_pull_request)   { Fixture.new('pull_requests/external_pull_request.json').to_json_hashie }
  let(:existing_pull_requests)  { Fixture.new('pull_requests/pull_requests.json').to_json_hashie }
  let(:existing_pull_commits)   { Fixture.new('pull_requests/commits.json').to_json_hashie }
  let(:comment_author)          { 'octocat' }
  let(:feature_branch_name)     { existing_pull_request.head.label[/[^:]+$/] }
  let(:base_branch_name)        { existing_pull_request.base.label[/[^:]+$/] }
  let(:existing_pull_comments)  {
    Fixture.new('pull_requests/comments.json.erb',
                repo_owner: user,
                repo_name: repo,
                comments: [{author: comment_author}],
                pull_request_number: existing_pull_request.number).to_json_hashie }
  let(:existing_issue_comments) {
    Fixture.new('issues/comments.json.erb',
                repo_owner: user,
                repo_name: repo,
                comments: [{author: comment_author}],
                pull_request_number: existing_pull_request.number).to_json_hashie }

  let(:pr) { GitReflow::GitServer::GitHub::PullRequest.new(existing_pull_request) }


  before do
    stub_command_line_inputs({
      "Please enter your GitHub username: "                                                 => user,
      "Please enter your GitHub password (we do NOT store this): "                          => password,
      "Please enter your Enterprise site URL (e.g. https://github.company.com):"            => enterprise_site,
      "Please enter your Enterprise API endpoint (e.g. https://github.company.com/api/v3):" => enterprise_api
    })

    allow(github.class).to receive(:remote_user).and_return(user)
    allow(github.class).to receive(:remote_repo_name).and_return(repo)
    allow(GitReflow::GitServer::PullRequest).to receive(:approval_regex).and_return(/(?i-mx:lgtm|looks good to me|:\+1:|:thumbsup:|:shipit:)/)
  end

  describe '#initialize(options)' do
    specify { expect(pr.number).to eql(existing_pull_request.number) }
    specify { expect(pr.description).to eql(existing_pull_request.body) }
    specify { expect(pr.html_url).to eql(existing_pull_request.html_url) }
    specify { expect(pr.feature_branch_name).to eql(feature_branch_name) }
    specify { expect(pr.base_branch_name).to eql(base_branch_name) }
    specify { expect(pr.build_status).to eql('success') }
    specify { expect(pr.source_object).to eql(existing_pull_request) }
  end

  describe '#commit_author' do
    subject { pr.commit_author }

    before do
      stub_request(:get, %r{#{GitReflow.git_server.class.api_endpoint}/repos/#{user}/#{repo}/pulls/#{existing_pull_request.number}/commits}).
        with(query: {"access_token" => "a1b2c3d4e5f6g7h8i9j0"}).
        to_return(:body => Fixture.new("pull_requests/commits.json").to_s, status: 201, headers: {content_type: "application/json; charset=utf-8"})
    end
    specify { expect(subject).to eql("#{existing_pull_commits.first.commit.author.name} <#{existing_pull_commits.first.commit.author.email}>") }
  end

  describe '#comments' do
    subject { pr.comments }

    context "Testing Appending of Comments" do
      before do
        FakeGitHub.new(
          repo_owner: user,
          repo_name: repo,
          pull_request: {
            number: existing_pull_request.number,
            comments: [{author: comment_author}]
          },
          issue: {
            number: existing_pull_request.number,
            comments: [{author: comment_author}]
          })
      end
      specify { expect(subject).to eql(existing_pull_comments.to_a + existing_issue_comments.to_a) }
    end

    context "Testing Nil Comments" do
      before do
        stub_request(:get, "https://api.github.com/repos/reenhanced/repo/pulls/2/comments?access_token=a1b2c3d4e5f6g7h8i9j0").
         with(:headers => {'Accept'=>'application/vnd.github.v3+json,application/vnd.github.beta+json;q=0.5,application/json;q=0.1', 'Accept-Charset'=>'utf-8', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Authorization'=>'token a1b2c3d4e5f6g7h8i9j0', 'User-Agent'=>'Github API Ruby Gem 0.15.0'}).
         to_return(:status => 200, :body => "", :headers => {})

        FakeGitHub.new(
          repo_owner: user,
          repo_name: repo,
          pull_request: {
            number: existing_pull_request.number,
            comments: nil
          },
          issue: {
            number: existing_pull_request.number,
            comments: nil
          })
      end
      specify { expect(subject).to eql([]) }
    end
  end

  describe '#reviewers' do
    subject { pr.reviewers }

    before do
      allow(existing_pull_request.user).to receive(:login).and_return('ringo')

      FakeGitHub.new(
        repo_owner: user,
        repo_name: repo,
        pull_request: {
          number: existing_pull_request.number,
          owner: existing_pull_request.user.login,
          comments: [{author: 'tito'}, {author: 'bobby'}, {author: 'ringo'}]
        },
        issue: {
          number: existing_pull_request.number,
          comments: [{author: 'ringo'}, {author: 'randy'}]
        })
    end

    specify { expect(subject).to eq(['tito', 'bobby', 'randy']) }
  end


  describe "#approved?" do
    subject { pr.approved? }

    context "no approvals and build success" do
      before do
        FakeGitHub.new(
          repo_owner: user,
          repo_name: repo,
          pull_request: {
            number: existing_pull_request.number,
            owner: existing_pull_request.head.user.login,
            comments: []
          })
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:minimum_approvals).and_return("0")
      end
      specify { expect(subject).to be_truthy }
    end

    context "all commenters must approve and minimum_approvals is nil" do
      before do
        FakeGitHub.new(
          repo_owner: user,
          repo_name: repo,
          pull_request: {
            number: existing_pull_request.number,
            owner: existing_pull_request.head.user.login,
            comments: []
          })
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:minimum_approvals).and_return(nil)
        allow(pr).to receive(:has_comments?).and_return(true)
        allow(pr).to receive(:approvals).and_return(["Simon"])
        allow(pr).to receive(:reviewers_pending_response).and_return([])
      end
      specify { expect(subject).to be_truthy }
    end

    context "all commenters must approve but we have no pending reviewers" do
      before do
        FakeGitHub.new(
          repo_owner: user,
          repo_name: repo,
          pull_request: {
            number: existing_pull_request.number,
            owner: existing_pull_request.head.user.login,
            comments: []
          })
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:minimum_approvals).and_return("")
        allow(pr).to receive(:has_comments?).and_return(true)
        allow(pr).to receive(:approvals).and_return(["Simon"])
        allow(pr).to receive(:reviewers_pending_response).and_return([])
      end
      specify { expect(subject).to be_truthy }
    end

    context "all commenters must approve but we have 1 pending reviewer" do
      before do
        FakeGitHub.new(
          repo_owner: user,
          repo_name: repo,
          pull_request: {
            number: existing_pull_request.number,
            owner: existing_pull_request.head.user.login,
            comments: []
          })
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:minimum_approvals).and_return("")
        allow(pr).to receive(:has_comments?).and_return(true)
        allow(pr).to receive(:approvals).and_return(["Simon"])
        allow(pr).to receive(:reviewers_pending_response).and_return(["Simon"])
      end
      specify { expect(subject).to be_falsy }
    end

    context "2 approvals required but we only have 1 approval" do
      before do
        FakeGitHub.new(
          repo_owner: user,
          repo_name: repo,
          pull_request: {
            number: existing_pull_request.number,
            owner: existing_pull_request.head.user.login,
            comments: []
          })
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:minimum_approvals).and_return("2")
        allow(pr).to receive(:approvals).and_return(["Simon"])
        allow(pr).to receive(:last_comment).and_return("LGTM")
      end
      specify { expect(subject).to be_falsy }
    end

    context "2 approvals required and we have 2 approvals but last comment is not approval" do
      before do
        FakeGitHub.new(
          repo_owner: user,
          repo_name: repo,
          pull_request: {
            number: existing_pull_request.number,
            owner: existing_pull_request.head.user.login,
            comments: []
          })
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:minimum_approvals).and_return("2")
        allow(pr).to receive(:approvals).and_return(["Simon", "Peter"])
        allow(pr).to receive(:last_comment).and_return("Boo")
      end
      specify { expect(subject).to be_falsy }
    end

    context "2 approvals required and we have 2 approvals and last comment is approval" do
      before do
        FakeGitHub.new(
          repo_owner: user,
          repo_name: repo,
          pull_request: {
            number: existing_pull_request.number,
            owner: existing_pull_request.head.user.login,
            comments: []
          })
        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:minimum_approvals).and_return("2")
        allow(pr).to receive(:approvals).and_return(["Simon", "Peter"])
        allow(pr).to receive(:last_comment).and_return("LGTM")
      end
      specify { expect(subject).to be_truthy }
    end
  end

  describe '#approvals' do
    subject { pr.approvals }

    context "no comments" do
      before do
        FakeGitHub.new(
          repo_owner: user,
          repo_name: repo,
          pull_request: {
            number: existing_pull_request.number,
            owner: existing_pull_request.head.user.login,
            comments: []
          })
      end

      specify { expect(subject).to eq([]) }
    end

    context "single reviewer without approval" do
      before do
        FakeGitHub.new(
          repo_owner: user,
          repo_name: repo,
          pull_request: {
            number: existing_pull_request.number,
            owner: existing_pull_request.head.user.login,
            comments: [{author: 'tito', body: 'This is some funky stuff'}]
          })
      end

      specify { expect(subject).to eq([]) }
    end

    context "single reviewer with approval" do
      before do
        FakeGitHub.new(
          repo_owner:   user,
          repo_name:    repo,
          pull_request: {
            number:   existing_pull_request.number,
            owner:    existing_pull_request.head.user.login,
            comments: [{author: 'tito', body: 'LGTM'}]
          })
      end

      specify { expect(subject).to eq(['tito']) }

      context "but a new commit has been introduced" do
        before do
          FakeGitHub.new(
            repo_owner:   user,
            repo_name:    repo,
            commits: [
              {
                author: user,
                pull_request_number: existing_pull_request.number,
                created_at: Chronic.parse("1 second ago")
              }
            ],
            pull_request: {
              number:   existing_pull_request.number,
              owner:    existing_pull_request.head.user.login,
              comments: [{author: 'tito', body: 'LGTM', created_at: Chronic.parse('1 minute ago')}]
            })
        end

        specify { expect(subject).to eq([]) }
      end
    end

    context "multiple reviewers with only one approval" do
      before do
        FakeGitHub.new(
          repo_owner:   user,
          repo_name:    repo,
          pull_request: {
            number:   existing_pull_request.number,
            owner:    existing_pull_request.head.user.login,
            comments: [{author: 'tito', body: 'LGTM'}, {author: 'ringo', body: 'Needs more cowbell.'}]
          })
      end

      specify { expect(subject).to eq(['tito']) }
    end

    context "multiple reviewers with all approvals" do
      before do
        FakeGitHub.new(
          repo_owner:   user,
          repo_name:    repo,
          pull_request: {
            number:   existing_pull_request.number,
            owner:    existing_pull_request.head.user.login,
            comments: [{author: 'tito', body: 'lgtm'}, {author: 'ringo', body: ':+1:'}]
          })

        allow(GitReflow::GitServer::GitHub::PullRequest).to receive(:approval_regex).and_return(/(?i-mx:lgtm|looks good to me|:\+1:|:thumbsup:|:shipit:)/)
      end

      context "2 approvals" do
        specify { expect(subject).to eq(['tito', 'ringo']) }
      end

      context "but a new commit has been introduced" do
        before do
          FakeGitHub.new(
            repo_owner:   user,
            repo_name:    repo,
            commits: [
              {
                author:              user,
                pull_request_number: existing_pull_request.number,
                created_at:          Chronic.parse("1 second ago")
              }
            ],
            pull_request: {
              number:   existing_pull_request.number,
              owner:    existing_pull_request.head.user.login,
              comments: [{author: 'tito', body: 'lgtm', created_at: Chronic.parse('1 minute ago')}, {author: 'ringo', body: ':+1:', created_at: Chronic.parse('1 minute ago')}]
            })
        end

        specify { expect(subject).to eq([]) }
      end
    end

  end

  describe '#last_comment' do
    subject { pr.last_comment }

    before do
      FakeGitHub.new(
        repo_owner:   user,
        repo_name:    repo,
        pull_request: {
          number:   existing_pull_request.number,
          owner:    existing_pull_request.head.user.login,
          comments: [{author: 'tito', body: 'lgtm'}, {author: 'ringo', body: 'Cha cha cha'}]
        })
    end

    specify { expect(subject).to eq('"Cha cha cha"') }
  end

  describe '#build' do
    let(:build) { Fixture.new('repositories/statuses.json').to_json_hashie.first }

    subject { pr.build }

    context "with an existing build" do
      specify { expect(subject.state).to eq(build.state) }
      specify { expect(subject.description).to eq(build.description) }
      specify { expect(subject.url).to eq(build.target_url) }
    end

    context "no build found" do
      before  { allow(GitReflow.git_server).to receive(:get_build_status).and_return(nil) }
      specify { expect(subject.state).to eq(nil) }
      specify { expect(subject.description).to eq(nil) }
      specify { expect(subject.url).to eq(nil) }
    end
  end

  describe '#merge!' do
    let(:inputs) do
      {
        :base => "base_branch",
        :title => "title",
        :message => "message"
      }
    end

    let(:lgtm_comment_authors) {
      ["simonzhu24", "reenhanced"]
    }

    let(:merge_response) { { :message => "Failure_Message" } }

    subject { pr.merge! inputs }

    before do
      allow(GitReflow).to receive(:git_server).and_return(github)
      allow(GitReflow::Config).to receive(:get)
      allow(GitReflow.git_server).to receive(:connection).and_return(github_api)
      allow(GitReflow.git_server).to receive(:get_build_status).and_return(Struct.new(:state, :description, :target_url).new())
      allow_any_instance_of(GitReflow::GitServer::PullRequest).to receive(:commit_message_for_merge).and_return('Bingo')
      allow_any_instance_of(GitReflow).to receive(:append_to_squashed_commit_message).and_return(true)
    end

    context "and force-merging" do
      let(:inputs) do
        {
          base:      "base_branch",
          title:     "title",
          message:   "message",
          skip_lgtm: true
        }
      end

      before { allow_any_instance_of(GitReflow::GitServer::PullRequest).to receive(:deliver?).and_return(true) }

      it "falls back on manual squash merge" do
        expect { subject }.to have_run_command "git merge --squash #{feature_branch_name}"
      end
    end

    context "and always deliver is set" do
      before do
        allow(GitReflow::Config).to receive(:get).with('reflow.always-deliver').and_return('true')
        allow(github_api).to receive_message_chain(:pull_requests, :merge).and_return(double(success?: true))
      end

      it "doesn't ask to confirm deliver" do
        expect(pr).to_not receive(:ask).with('This is the current status of your Pull Request. Are you sure you want to deliver? ')
        subject
      end
    end

    context "and not suqash merging" do
      let(:inputs) do
        {
          base:    "base_branch",
          title:   "title",
          message: "message",
          squash:  false
        }
      end

      before do
        allow_any_instance_of(GitReflow::GitServer::PullRequest).to receive(:deliver?).and_return(true)
        allow(github_api).to receive_message_chain(:pull_requests, :merge).and_return(double(success?: true))
      end

      it "doesn't ask Github to squash merge" do
        expect(github_api).to receive_message_chain(:pull_requests, :merge).with(
          user,
          repo,
          pr.number.to_s,
          {
            "commit_title"   => "#{inputs[:title]}",
            "commit_message" => "#{inputs[:message]}\n",
            "sha"            => pr.head.sha,
            "merge_method"   => "merge"
          }
        )

        subject
      end
    end

    context "finds pull request but merge response fails" do
      before do
        allow(GitReflow::GitServer::GitHub).to receive_message_chain(:connection, :pull_requests, :merge).and_return(merge_response)
        allow(merge_response).to receive(:success?).and_return(false)
        allow_any_instance_of(GitReflow::GitServer::GitHub::PullRequest).to receive(:approvals).and_return(lgtm_comment_authors)
        allow(pr).to receive(:deliver?).and_return(true)
        allow(merge_response).to receive(:to_s).and_return("Merge failed")
      end

      it "throws an error" do
        expect { subject }.to have_said "Merge failed", :deliver_halted
        expect { subject }.to have_said "There were problems commiting your feature... please check the errors above and try again.", :error
      end
    end
  end

  describe '.create(options)' do
    let(:title) { 'Bone Saw is ready!' }
    let(:body)  { 'Snap into a Slim Jim!' }
    let(:base_branch_name) { 'base-branch' }
    let(:pull_request_response) do
      Fixture.new('pull_requests/pull_request.json.erb',
                  number:      2,
                  title:       title,
                  body:        body,
                  base_branch: base_branch_name,
                  repo_owner:  user,
                  repo_name:   repo)
    end

    subject { GitReflow::GitServer::GitHub::PullRequest.create(title: title, body: body, base: base_branch_name) }

    before do
      stub_request(:post, %r{/repos/#{user}/#{repo}/pulls}).
        to_return(body: pull_request_response.to_s, status: 201, headers: {content_type: "application/json; charset=utf-8"})
    end

    specify { expect(subject.class.to_s).to eql('GitReflow::GitServer::GitHub::PullRequest') }
    specify { expect(subject.title).to eql(title) }
    specify { expect(subject.description).to eql(body) }
    specify { expect(subject.base_branch_name).to eql(base_branch_name) }
  end

  describe '.find_open(options)' do
    let(:feature_branch) { 'new-feature' }
    let(:base_branch)    { 'base-branch' }

    subject { GitReflow::GitServer::GitHub::PullRequest.find_open(from: feature_branch, to: base_branch) }

    before do
      allow(GitReflow.git_server.class).to receive(:current_branch).and_return(feature_branch)
      FakeGitHub.new(
        repo_owner:   user,
        repo_name:    repo,
        pull_request: {
          number:   existing_pull_request.number,
          owner:    existing_pull_request.head.user.login,
          base_branch: base_branch,
          feature_branch: feature_branch
        })
    end

    specify { expect(subject.class.to_s).to eql('GitReflow::GitServer::GitHub::PullRequest') }
    specify { expect(subject.number).to eql(existing_pull_request.number) }

    context "without any options" do
      let(:base_branch) { 'master' }
      subject           { GitReflow::GitServer::GitHub::PullRequest.find_open() }
      it "defaults to the current branch as the feature branch and 'master' as the base branch" do
        expect(subject.class.to_s).to eql('GitReflow::GitServer::GitHub::PullRequest')
        expect(subject.number).to eql(existing_pull_request.number)
      end
    end
  end

end
