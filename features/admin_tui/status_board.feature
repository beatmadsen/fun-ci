Feature: Status board display
  As a developer using fun-ci
  I want a single-screen status board showing pipeline runs
  So that I can glance at the state of my CI pipelines

  The TUI is a departure board -- you look, you know, you go.
  Each row shows: commit, branch, three stages with times, outcome, relative time.
  No table headers. No drill-down. Everything visible on one screen.

  Scenario: Board shows a completed pipeline run with all stages
    Given a pipeline run for commit "a3f7c01" on branch "main" has completed
    And the build stage passed in 0.3 seconds
    And the fast suite passed in 1.8 seconds
    And the slow suite passed in 47 seconds
    When I open the admin TUI
    Then I should see a row with commit "a3f7c01" and branch "main"
    And the row should show "Build 0.3s"
    And the row should show "Fast 1.8s"
    And the row should show "Slow 47s"
    And the row should show status "PASSED"

  Scenario: Board shows multiple runs in reverse chronological order
    Given the following pipeline runs exist:
      | commit  | branch         | outcome | completed_ago |
      | a3f7c01 | main           | passed  | 2m            |
      | e92b4da | fix/login-bug  | passed  | 14m           |
      | 7c1d8f3 | feat/search    | passed  | 38m           |
    When I open the admin TUI
    Then the first row should show commit "a3f7c01"
    And the second row should show commit "e92b4da"
    And the third row should show commit "7c1d8f3"

  Scenario: Board shows relative time for each run
    Given a pipeline run for commit "a3f7c01" on branch "main" completed 2 minutes ago
    When I open the admin TUI
    Then the row for commit "a3f7c01" should show "2m ago"

  Scenario: Failed stage shows FAIL label with elapsed time
    Given a pipeline run for commit "91de003" on branch "fix/nil-crash" has failed
    And the build stage passed in 0.1 seconds
    And the fast suite failed at 6.2 seconds
    When I open the admin TUI
    Then the row should show "Fast FAIL 6.2s"
    And the row should show status "FAILED"

  Scenario: Stages after a failure show as not reached
    Given a pipeline run where the fast suite failed
    When I open the admin TUI
    Then the slow suite stage should show "--"

  Scenario: Timed out stage shows TIMEOUT label with budget time
    Given a pipeline run for commit "d4e5f67" on branch "feat/search" has timed out
    And the build stage passed in 0.2 seconds
    And the fast suite timed out at 10 seconds
    When I open the admin TUI
    Then the row should show "Fast TIMEOUT 10s"
    And the row should show status "TIMED OUT"

  Scenario: Scheduled run shows as pending with no stage details
    Given a pipeline run for commit "f001ba2" on branch "feat/cache" is scheduled
    When I open the admin TUI
    Then the row should show "Scheduled..."
    And the row should not show stage columns

  Scenario: Cancelled run shows neutral status
    Given a pipeline run for commit "d4e5f67" on branch "feat/search" was cancelled
    When I open the admin TUI
    Then the row should show status "CANCELLED"

  Scenario: Board fills available terminal height
    Given 30 pipeline runs exist
    And the terminal height is 24 lines
    When I open the admin TUI
    Then the board should show approximately 15 rows
    And older runs beyond the visible area are simply not shown
