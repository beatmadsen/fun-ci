Feature: Keyboard navigation
  As a developer using the admin TUI
  I want to navigate with j/k keys
  So that I can select a pipeline run to cancel if needed

  The cursor is invisible by default. The board is a status display
  first. You only enter "interactive mode" when you want to cancel
  something. Three keys is the entire interface.

  Scenario: Cursor is invisible by default
    Given pipeline runs exist on the board
    When I open the admin TUI
    Then no cursor or row selection should be visible

  Scenario: Pressing j reveals cursor on the first row
    Given pipeline runs exist on the board
    When I open the admin TUI
    And I press "j"
    Then the first row should be highlighted as selected

  Scenario: Pressing j moves cursor down
    Given pipeline runs exist on the board
    And the cursor is on the first row
    When I press "j"
    Then the second row should be highlighted as selected
    And the first row should no longer be highlighted

  Scenario: Pressing k moves cursor up
    Given pipeline runs exist on the board
    And the cursor is on the second row
    When I press "k"
    Then the first row should be highlighted as selected

  Scenario: Cursor does not move past the last row
    Given 3 pipeline runs exist on the board
    And the cursor is on the third row
    When I press "j"
    Then the cursor should remain on the third row

  Scenario: Cursor does not move above the first row
    Given pipeline runs exist on the board
    And the cursor is on the first row
    When I press "k"
    Then the cursor should remain on the first row

  Scenario: Down arrow key works the same as j
    Given pipeline runs exist on the board
    When I open the admin TUI
    And I press the Down arrow key
    Then the first row should be highlighted as selected

  Scenario: Up arrow key works the same as k
    Given pipeline runs exist on the board
    And the cursor is on the second row
    When I press the Up arrow key
    Then the first row should be highlighted as selected

  Scenario: Pressing q quits the TUI immediately
    When I open the admin TUI
    And I press "q"
    Then the TUI should exit
    And control should return to the terminal
