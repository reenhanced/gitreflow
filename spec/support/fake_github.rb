require 'rspec/mocks'
require 'webmock'
require 'chronic'

class FakeGitHub
  include WebMock::API

  attr_accessor :repo_owner, :repo_name

  DEFAULT_COMMIT_AUTHOR = "reenhanced".freeze
  DEFAULT_COMMIT_TIME   = "1 minute ago".freeze

  # EXAMPLE:
  #
  #   FakeGitHub.new(repo_owner: user, repo_name: repo,
  #     pull_request: {
  #       number: existing_pull_request.number,
  #       comments: [{author: comment_author}]
  #     },
  #     issue: {
  #       comments: [{author: comment_author}]
  #     })
  #
  def initialize(repo_owner:, repo_name:, pull_request: {}, issue: {}, commits: [])

    self.repo_owner = repo_owner
    self.repo_name  = repo_name

    stub_github_request(:pull_request, pull_request) if pull_request
    stub_github_request(:issue, issue) if issue
    stub_github_request(:commits, commits) if commits.any?

    if pull_request and (issue.none? or !issue[:comments])
      stub_github_request(:issue, pull_request.merge({comments: []}))
    end

    if pull_request and commits.none?
      stub_github_request(:commits, [{
        author:              pull_request[:owner] || DEFAULT_COMMIT_AUTHOR,
        created_at:          Chronic.parse(DEFAULT_COMMIT_TIME)
      }])
    end

    self
  end

  def stub_github_request(object_to_stub, object_data)
    case object_to_stub
    when :commits
      commits_response = Fixture.new('repositories/commits.json.erb',
                            repo_owner:          repo_owner,
                            repo_name:           repo_name,
                            commits:             object_data)
      commits_response.to_json_hashie.each_with_index do |commit, index|
        stub_request(:get, %r{/repos/#{self.repo_owner}/(#{self.repo_name}/)?commits/#{commit.sha}\?}).
          to_return(
            body: commit.to_json.to_s,
            status: 201,
            headers: {content_type: "application/json; charset=utf-8"})
      stub_request(:get, %r{/repos/#{self.repo_owner}/commits\Z}).
        to_return(
          body: commits_response.to_s,
          status: 201,
          headers: {content_type: "application/json; charset=utf-8"})
      end
    when :issue
      # Stubbing issue comments
      if object_data[:comments]
        stub_request(:get, %r{/repos/#{self.repo_owner}/(#{self.repo_name}/)?issues/#{object_data[:number] || 1}/comments}).
          with(query: {'access_token' => 'a1b2c3d4e5f6g7h8i9j0'}).
          to_return(body: Fixture.new('issues/comments.json.erb',
                                         repo_owner:          self.repo_owner,
                                         repo_name:           self.repo_name,
                                         comments:            object_data[:comments],
                                         pull_request_number: object_data[:number] || 1,
                                         body:                object_data[:body] || 'Hammer time',
                                         created_at:          object_data[:created_at] || Chronic.parse("1.minute ago")).to_s,
                    status: 201,
                    headers: {content_type: "application/json; charset=utf-8"})
      else
        stub_request(:get, %r{/repos/#{self.repo_owner}/(#{self.repo_name}/)?issues/#{object_data[:number] || 1}/comments}).
          with(query: {'access_token' => 'a1b2c3d4e5f6g7h8i9j0'}).
          to_return(body: '[]', status: 201, headers: {content_type: "application/json; charset=utf-8"})
      end
    when :pull_request
      # EXAMPLES
      stubbed_pull_request_response = Fixture.new('pull_requests/pull_request.json.erb',
                                                  number:             object_data[:number] || 1,
                                                  title:              object_data[:title] || 'Please merge these changes',
                                                  body:               object_data[:body] || 'Bone saw is ready.',
                                                  state:              object_data[:state] || 'open',
                                                  owner:              object_data[:owner] || 'octocat',
                                                  feature_repo_owner: object_data[:feature_repo_owner] || self.repo_owner,
                                                  feature_branch:     object_data[:feature_branch] || 'new-feature',
                                                  base_branch:        object_data[:base_branch] || 'master',
                                                  repo_owner:         self.repo_owner,
                                                  repo_name:          self.repo_name)

      stub_request(:get, "#{GitReflow::GitServer::GitHub.api_endpoint}/repos/#{self.repo_owner}/#{self.repo_name}/pulls/#{object_data[:number]}").
        with(query: {'access_token' => 'a1b2c3d4e5f6g7h8i9j0'}).
        to_return(body: stubbed_pull_request_response.to_s, status: 201, headers: {content_type: "application/json; charset=utf-8"})
      stub_request(:get, "#{GitReflow::GitServer::GitHub.api_endpoint}/repos/#{self.repo_owner}/#{self.repo_name}/pulls")
        .with(:query => {'access_token' => 'a1b2c3d4e5f6g7h8i9j0', 'base' => object_data[:base_branch] || 'master', 'head' => "#{object_data[:feature_repo_owner] || self.repo_owner}:#{object_data[:feature_branch] || "new-feature"}", 'state' => object_data[:state] || 'open'}).
        to_return(:body => "[#{stubbed_pull_request_response.to_s}]", :status => 201, :headers => {:content_type => "application/json; charset=utf-8"})

      # Stubbing pull request comments
      if object_data[:comments]
        stub_request(:get, %r{/repos/#{self.repo_owner}/(#{self.repo_name}/)?pulls/#{object_data[:number] || 1}/comments}).
          with(query: {'access_token' => 'a1b2c3d4e5f6g7h8i9j0'}).
          to_return(body: Fixture.new('pull_requests/comments.json.erb',
                                      repo_owner:          self.repo_owner,
                                      repo_name:           self.repo_name,
                                      comments:            object_data[:comments],
                                      pull_request_number: object_data[:number] || 1,
                                      created_at:          object_data[:created_at] || Time.now).to_s,
                    status: 201,
                    headers: {content_type: "application/json; charset=utf-8"})
      end

      # Stubbing pull request commits
      #stub_get(%r{#{GitReflow::GitServer::GitHub.api_endpoint}/repos/#{user}/#{repo}/pulls/#{existing_pull_request.number}/commits}).
      #  with(query: {"access_token" => "a1b2c3d4e5f6g7h8i9j0"}).
      #  to_return(:body => Fixture.new("pull_requests/commits.json").to_s, status: 201, headers: {content_type: "application/json; charset=utf-8"})
    end
  end
end

