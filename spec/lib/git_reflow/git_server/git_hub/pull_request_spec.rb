require 'spec_helper'

describe GitReflow::GitServer::GitHub::PullRequest do

  describe ".create" do
    pending "creates a pull request and returns an instance with the result"
  end

  describe ".find_open" do
    pending "searches GitHub for an open pull request matching the current branch and base branch"
  end

  describe "#build_status" do
    pending "returns the state of the build"
  end

  describe "#commit_author" do
    pending "returns the author name and email for the first commit on the pull request"
  end

  describe "#reviewers" do
    pending "returns an array usernames that have commented on the pull request"
  end

  describe "#approvals" do
    pending "returns an array usernames that have approved the pull request"
  end

  describe "#comments" do
    pending "returns an array of comments on the pull request"
  end

  describe "#last_comment" do
    pending "returns the last comment on the pull request"
  end

  describe "#approved?" do
    context "approval minimum is not set" do
      pending "it falls back to default approval checks"
    end

    context "approval minimum is > 0" do
      context "approval minimums are met" do
        context "and last comment is an approval" do
          pending "returns true"
        end
        context "but last comment is not an approval" do
          pending "returns false"
        end
      end

      context "approval minimums are not met" do
        pending "returns false"
      end
    end
  end

  describe "#merge!" do
    context "force-merging" do
      pending "falls back on manual squash merge"
    end

    context "user approves delivery" do
      pending "need full spec"
    end
  end

end
