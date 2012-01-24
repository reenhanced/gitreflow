Feature: User installs gem
  As a user
  When I install a gem
  It should initialize the gem configuration

  Scenario: User installs gem
    Given the global git config exists
    When we build and install the gem
    Then we should see the reflow alias in the global git config
