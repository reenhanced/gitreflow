Feature: User installs gem
  As a user
  When I install a gem
  It should initialize the gem configuration

  Scenario: User installs gem
    When I build and install the gem
    And I successfully run `git-reflow`
    Then the output should contain "usage: git-reflow [global options] command [command options]"

  Scenario: User sets up GitHub
    When I run `git-reflow setup` interactively
    And I type "user"
    And I type "password"
    Then the output should contain "Please enter your GitHub username: "
    And the output should contain "Please enter your GitHub password (we do NOT store this): "
    And the output should contain "Your GitHub account was successfully setup!"
