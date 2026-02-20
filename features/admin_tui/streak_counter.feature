Feature: Streak counter
  As a developer who enjoys seeing consecutive passing builds
  I want a streak counter in the header
  So that I get a fun reward for keeping the build green

  The streak is the fun element. When the number is high, it feels good.
  It counts consecutive PASSED runs. Running does not affect it.
  Breaking the streak is factual, not alarming.

  Scenario: Header shows streak count when builds are passing
    Given the last 7 pipeline runs all passed consecutively
    When I open the admin TUI
    Then the header should show "7 in a row!"
    And the streak text should be displayed in green

  Scenario: Streak resets when a run fails
    Given 5 pipeline runs passed and then 1 failed
    When I open the admin TUI
    Then the header should show "Streak broken"
    And "Streak broken" should be displayed in default white, not red

  Scenario: Streak resets when a run times out
    Given 3 pipeline runs passed and then 1 timed out
    When I open the admin TUI
    Then the header should show "Streak broken"

  Scenario: Running pipeline does not affect the streak
    Given the last 4 pipeline runs all passed
    And a new pipeline run is currently running
    When I open the admin TUI
    Then the header should show "4 in a row!"

  Scenario: Streak updates live when a running pipeline completes as passed
    Given the streak is "4 in a row!" and a pipeline is running
    When the running pipeline completes successfully
    Then the header should update to show "5 in a row!"

  Scenario: No streak shown when there are no completed runs
    Given no pipeline runs have completed
    When I open the admin TUI
    Then the header should not show a streak counter

  Scenario: Streak of one is still shown
    Given only 1 pipeline run has passed
    When I open the admin TUI
    Then the header should show "1 in a row!"
