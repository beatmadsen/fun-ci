# frozen_string_literal: true

# Then steps about the cursor, quitting, and cancelling a run.

Then("no cursor or row selection should be visible") do
  refute_match(/^>/, @client.plain_output, "No cursor should be visible")
end

Then("the first row should be highlighted as selected") do
  assert_cursor_on(0)
end

Then("the second row should be highlighted as selected") do
  assert_cursor_on(1)
end

Then("the first row should no longer be highlighted") do
  first_row = run_rows.first
  assert first_row, "Board should still show its first row"
  refute_match(AdminTuiStepHelpers::CURSOR, first_row, "First row should not have cursor")
end

Then("the cursor should remain on the third row") do
  assert_cursor_on(2)
end

Then("the cursor should remain on the first row") do
  assert_cursor_on(0)
end

Then("the TUI should exit") do
  assert @client.exited?, "The run loop should have returned after q"
end

Then("control should return to the terminal") do
  assert_equal %i[raw cooked], @client.terminal_modes, "The terminal should be put back in cooked mode on exit"
end

# Immediately: in the frame drawn in answer to the key, with no refresh in between.
Then("the row should immediately update to show status {string}") do |status|
  assert_match(/#{escaped(status)}/, @client.plain_output, "Status should update to #{status}")
end

Then("no confirmation prompt should appear") do
  refute_match(AdminTuiStepHelpers::PROMPT, @client.plain_output, "No confirmation prompt should appear")
end

Then("a confirmation prompt should appear") do
  assert @client.tui.confirming?, "Confirmation prompt should be showing"
  assert_match(AdminTuiStepHelpers::PROMPT, @client.plain_output, "The prompt should be on screen")
end

Then("the prompt should show {string}") do |text|
  prompt = @client.board_lines.find { |line| line.match?(AdminTuiStepHelpers::PROMPT) }
  assert prompt, "A prompt should be on screen"
  assert_equal text, prompt.strip, "The prompt should read '#{text}'"
end

Then("every process of the running pipeline should be killed, stage scripts included") do
  assert_equal @client.recorded_processes(@commit).map { |pid| ["KILL", pid] }, @client.signals_sent
end

Then("the row should update to show status {string}") do |status|
  @client.open_tui
  assert_match(/#{escaped(status)}/, @client.plain_output, "Status should show #{status}")
end

Then("the confirmation prompt should disappear") do
  refute @client.tui.confirming?, "Confirmation prompt should be gone"
  refute_match(AdminTuiStepHelpers::PROMPT, @client.plain_output, "The prompt should be off screen")
end

Then("the pipeline should continue running") do
  @client.open_tui
  assert_match(/RUNNING/, @client.plain_output, "Pipeline should still be running")
end

# Without colour: dim and reset are the only styles on the row.
Then("the cancelled row should show stage times without color") do
  row = raw_row("CANCELLED")
  assert row, "Should show a CANCELLED row"
  assert_match(/Build \d/, row, "The cancelled row should show stage times")
  assert_equal %w[0 2], sgr_codes(row), "The cancelled row should be dim, with no colour inside it"
end

Then("nothing should happen") do
  assert_equal @client.previous_plain_output, @client.plain_output, "The board should not change"
end
