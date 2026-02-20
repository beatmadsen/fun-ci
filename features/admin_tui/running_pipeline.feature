Feature: Running pipeline display
  As a developer watching an active pipeline
  I want to see animated progress on the active stage
  So that I can tell the system is alive and know what is happening right now

  The spinner is a heartbeat -- you can tell the system is alive
  from across the room. Combined with a live timer, it creates a
  subtle pulse that draws the eye to the active row.

  Scenario: Active stage shows animated braille spinner
    Given a pipeline run currently in the fast suite stage
    When I open the admin TUI
    Then the fast suite stage should display a braille spinner
    And the spinner should cycle through its frames at approximately 100ms

  Scenario: Active stage shows live elapsed timer
    Given a pipeline run currently in the fast suite stage at 3 seconds elapsed
    When I watch the admin TUI for 2 seconds
    Then the elapsed time should increment from 3s to 5s

  Scenario: Only the active stage shows the spinner
    Given a pipeline run currently in the slow suite stage
    And the build stage passed in 0.2 seconds
    And the fast suite passed in 2.4 seconds
    When I open the admin TUI
    Then the build stage should show "Build 0.2s" in green without a spinner
    And the fast suite should show "Fast 2.4s" in green without a spinner
    And the slow suite should show a spinner with elapsed time in cyan

  Scenario: Running row has a subtle highlight
    Given a pipeline run currently in the slow suite stage
    When I open the admin TUI
    Then the running row should have a faint background highlight

  Scenario: Only one spinner visible at a time
    Given two pipeline runs are both in a running state
    When I open the admin TUI
    Then only the most recent running pipeline should show a spinner

  Scenario: Early pipeline shows unreached stages as dim dashes
    Given a pipeline run currently in the fast suite stage
    When I open the admin TUI
    Then the slow suite should show "--" in dim
