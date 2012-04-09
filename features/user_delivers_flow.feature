@gem
Feature: User delivers a flow
  As a User
  When I deliver a flow
  I should be on the base branch with the feature branch merged in

  Background:
    Given I have a git repository with a branch named "master" checked out
    And I have a remote git repository named "origin"
    And I have a new branch named "banana" checked out

  Scenario: User runs git-reflow deliver without any parameters
    When I run `git-reflow deliver` interactively
    Then the output should contain "Successfully created pull request #1: Commit Title\nPull Request URL: http://github.com/reenhanced/banana/pulls/1\n"

  Scenario: User runs git-reflow deliver with a correct pull request number
    Given I have a pull request numbered "1" to merge "banana" into "master"
    When I run `git-reflow deliver 1` interactively
    Then the output should contain "Merged \"banana\" into \"master\""
    And the output should contain "Pull request: http://github.com/reenhanced/banana/pulls/1\n"
