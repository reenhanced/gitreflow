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
    And I have a remote git repository named "origin"
    And the remote repository named "origin" has changes on the "master" branch
    And I cd to "master_repo"
    When I run `git-reflow start new-branch`
    Then the output should match /\* \[new branch\]\s* master\s* \-\> new\-branch/
    And the output should match /\* \[new branch\]\s* master\s* \-\> origin.master/
    And the output should contain "Switched to a new branch 'new-branch'"
