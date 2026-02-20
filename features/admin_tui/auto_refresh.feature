Feature: Auto-refresh behavior
  As a developer watching the status board
  I want the board to stay current without manual intervention
  So that I never have to wonder if the data is stale

  There is no manual refresh key. The board is always live.
  Refresh cadence adapts to activity level.
  Only changed rows re-render -- no full screen redraw, no flicker.

  Scenario: Board refreshes every second when a pipeline is running
    Given a pipeline run is currently running
    When I watch the admin TUI
    Then the board should refresh approximately every 1 second

  Scenario: Board refreshes every 5 seconds when everything is settled
    Given all pipeline runs are completed
    When I watch the admin TUI
    Then the board should refresh approximately every 5 seconds

  Scenario: New pipeline run appears without manual action
    Given I am viewing the admin TUI with all runs completed
    When a new pipeline run is triggered externally
    Then the new run should appear on the board within 5 seconds

  Scenario: Running pipeline transitioning to completed updates in place
    Given a pipeline run is currently running on the board
    When the running pipeline completes
    Then the row should update from "RUNNING" to "PASSED" in place
    And no full screen redraw should occur

  Scenario: Refresh switches to fast cadence when a new run starts
    Given all pipeline runs are completed and refresh is at 5 second cadence
    When a new pipeline run begins
    Then the refresh cadence should switch to approximately every 1 second
