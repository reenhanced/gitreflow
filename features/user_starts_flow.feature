@gem
Feature: User starts a new flow
  As a User
  When I start a new flow
  I should be on a new working feature branch

  Scenario: User runs git-reflow start without any parameters
    When I run `git-reflow start`
    Then the output should contain "usage: git-reflow start [new-branch-name]"

  Scenario: User runs git-reflow start with new branch name
    Given I have a git repository with a branch named "master"
    When I run `git-reflow start new-branch`
    Then the stdout should contain "git push origin master:refs/heads/new-branch"
