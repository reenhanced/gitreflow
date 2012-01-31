Feature: User starts a new flow
  As a User
  When I start a new flow
  I should be on a new working feature branch

  @gem
  Scenario: User runs git-reflow start without any parameters
    When I run `git-reflow start`
    Then the output should contain "usage: git-reflow start [new-branch-name]"
