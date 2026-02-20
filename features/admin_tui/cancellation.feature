Feature: Cancel pipeline runs
  As a developer who committed by accident or wants to stop a stale pipeline
  I want to cancel scheduled or running pipeline jobs
  So that I do not waste time on pipelines I no longer care about

  Cancelling a scheduled job is instant and harmless.
  Cancelling a running job kills a process and requires confirmation.
  Cancelling a completed job does nothing.

  Scenario: Cancel a scheduled job instantly without confirmation
    Given a pipeline run for commit "f001ba2" on branch "feat/cache" is scheduled
    And the cursor is on that scheduled row
    When I press "c"
    Then the row should immediately update to show status "CANCELLED"
    And no confirmation prompt should appear

  Scenario: Cancel a running job shows confirmation prompt
    Given a pipeline run for commit "d4e5f67" on branch "feat/search" is running
    And the cursor is on that running row
    When I press "c"
    Then a confirmation prompt should appear
    And the prompt should show "Cancel feat/search (d4e5f67)? y / n"

  Scenario: Confirming cancellation of a running job
    Given a confirmation prompt is showing for commit "d4e5f67" on branch "feat/search"
    When I press "y"
    Then the running pipeline process should be killed
    And the row should update to show status "CANCELLED"
    And the confirmation prompt should disappear

  Scenario: Declining cancellation dismisses the prompt
    Given a confirmation prompt is showing for commit "d4e5f67" on branch "feat/search"
    When I press "n"
    Then the confirmation prompt should disappear
    And the pipeline should continue running

  Scenario: Escape key also dismisses the confirmation prompt
    Given a confirmation prompt is showing for commit "d4e5f67" on branch "feat/search"
    When I press Escape
    Then the confirmation prompt should disappear
    And the pipeline should continue running

  Scenario: Cancelled running job row becomes dim
    Given a running pipeline was just cancelled via confirmation
    When I look at the board
    Then the cancelled row should show stage times without color
    And the status "CANCELLED" should be displayed in dim

  Scenario: Pressing c on a completed job does nothing
    Given a pipeline run for commit "a3f7c01" on branch "main" has completed
    And the cursor is on that completed row
    When I press "c"
    Then nothing should happen
    And no confirmation prompt should appear

  Scenario: Pressing c with no cursor visible does nothing
    Given pipeline runs exist on the board
    And the cursor is invisible
    When I press "c"
    Then nothing should happen
