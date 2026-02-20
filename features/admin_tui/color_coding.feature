Feature: Color-coded pipeline states
  As a developer glancing at the status board
  I want states to be color-coded
  So that I can scan the board by color without reading text

  A wall of green means everything is fine.
  Red draws the eye to failures.
  Yellow signals a design problem (timeout), not a code bug.
  Cyan shows what is active right now.
  Dim means "not interesting yet" or "secondary information."

  Scenario: Passed stages and status are green
    Given a pipeline run that passed all stages
    When I open the admin TUI
    Then the stage times should be displayed in green
    And the "PASSED" status should be displayed in bold green

  Scenario: Failed stages and status are red
    Given a pipeline run where the fast suite failed
    When I open the admin TUI
    Then the failed stage should be displayed in bold red
    And the "FAILED" status should be displayed in bold red

  Scenario: Timed out stages and status are yellow
    Given a pipeline run where the fast suite timed out
    When I open the admin TUI
    Then the timed out stage should be displayed in bold yellow
    And the "TIMED OUT" status should be displayed in bold yellow

  Scenario: Running stage is cyan with active spinner
    Given a pipeline run currently in the slow suite stage
    When I open the admin TUI
    Then the active stage should be displayed in cyan
    And the "RUNNING" status should be displayed in bold cyan

  Scenario: Unreached stages are dim
    Given a pipeline run where the fast suite is active
    When I open the admin TUI
    Then the slow suite stage showing "--" should be displayed in dim

  Scenario: Scheduled rows are entirely dim
    Given a pipeline run that is scheduled but not yet started
    When I open the admin TUI
    Then the entire row should be displayed in dim

  Scenario: Relative time is always dim
    Given any pipeline run on the board
    When I open the admin TUI
    Then the relative time should be displayed in dim

  Scenario: Cancelled status is dim and neutral
    Given a pipeline run that was cancelled
    When I open the admin TUI
    Then the "CANCELLED" status should be displayed in dim

  Scenario: Header bar uses white text on charcoal background
    When I open the admin TUI
    Then the header should show "fun-ci" in white on a charcoal background

  Scenario: Footer keys are dim
    When I open the admin TUI
    Then the footer showing key bindings should be displayed in dim
