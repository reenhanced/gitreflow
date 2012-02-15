@gem
Feature: User delivers a flow
  As a User
  When I deliver a flow
  I should be on the base branch with the feature branch merged in

  Scenario: User runs git-reflow deliver without any parameters
    Given I have a git repository with a branch named "master" checked out
    And I have a remote git repository named "origin"
    And I have a branch named "banana" checked out
    When I run `git-reflow deliver`
    Then the output should contain "Created a pull #1 to merge banana into master"

  Scenario: User runs git-reflow deliver with a correct pull request number
    Given I have a git repository with a branch named "master" checked out
    And I have a remote git repository named "origin"
    And I have a branch named "banana" checked out
    And I have a pull request numbered "1" to merge "banana" into "master"
    When I run `git-reflow deliver 1`
    Then the output should contain "Merged \"banana\" into \"master\""
