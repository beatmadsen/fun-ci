Feature: Terminal resize handling
  As a developer using the fun-ci TUI
  I want the interface to adapt when I resize my terminal window
  So that the display fills the available space and stays readable

  The TUI should detect terminal resize (SIGWINCH) and immediately
  redraw at the new width. The header stretches to fill the terminal,
  and the content reflows to fit.

  Scenario: Header stretches to fill new terminal width after resize
    Given a completed pipeline run exists
    And the TUI is open at terminal width 80
    When the terminal is resized to width 120
    Then the header should fill 120 columns

  Scenario: TUI picks up new terminal width on each render
    Given a completed pipeline run exists
    And the TUI is open with a width provider returning 80
    When the width provider starts returning 120
    And the TUI renders again
    Then the header should fill 120 columns
