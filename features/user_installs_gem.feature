Feature: User installs gem
  As a user
  When I install a gem
  It should initialize the gem configuration

  Scenario: User installs gem
    When I build and install the gem
    And I successfully run "git reflow"
    Then the output should contain "usage: git reflow <subcommand>"
