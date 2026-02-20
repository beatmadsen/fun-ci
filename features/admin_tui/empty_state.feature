Feature: Empty state on first launch
  As a developer who just installed fun-ci
  I want a helpful empty state when no runs exist
  So that I know how to get started

  Centered, minimal, calm. No banner, no decoration.
  Just the two commands you need.

  Scenario: First launch with no pipeline runs
    Given no pipeline runs exist
    When I open the admin TUI
    Then the board should show "No runs yet."
    And the board should show "Trigger one: fun-ci trigger HEAD"
    And the board should show "Or hook it: fun-ci install-hook pre-push"

  Scenario: Empty state footer only shows quit
    Given no pipeline runs exist
    When I open the admin TUI
    Then the footer should show only "q quit"
    And the footer should not show "j/k move" or "c cancel"

  Scenario: Empty state still shows header
    Given no pipeline runs exist
    When I open the admin TUI
    Then the header should show "fun-ci"
    And the header should not show a streak counter
