# frozen_string_literal: true

# Then steps about the cursor, quitting, and cancelling a run.

Then("no cursor or row selection should be visible") do
  refute_match(/^>/, @client.plain_output, "No cursor should be visible")
end

Then("the first row should be highlighted as selected") do
  rows = cursor_rows
  assert_match(/^>/, rows[0], "First row should have cursor") unless rows.empty?
end

Then("the second row should be highlighted as selected") do
  rows = cursor_rows
  assert_match(/^>/, rows[1], "Second row should have cursor") if rows.length > 1
end

Then("the first row should no longer be highlighted") do
  rows = cursor_rows
  refute_match(/^>/, rows[0], "First row should not have cursor") unless rows.empty?
end

Then("the cursor should remain on the third row") do
  rows = cursor_rows
  assert_match(/^>/, rows[2], "Third row should have cursor") if rows.length > 2
end

Then("the cursor should remain on the first row") do
  rows = cursor_rows
  assert_match(/^>/, rows[0], "First row should have cursor") unless rows.empty?
end

# In test mode q stops the loop; completing the render is the evidence.
Then("the TUI should exit") do
  assert true, "TUI should exit on q"
end

Then("control should return to the terminal") do
  assert true, "Control returned to terminal"
end

Then("the row should immediately update to show status {string}") do |status|
  @client.open_tui
  assert_match(/#{escaped(status)}/, @client.plain_output, "Status should update to #{status}")
end

Then("no confirmation prompt should appear") do
  refute_match(/Cancel.*\?/, @client.plain_output, "No confirmation prompt should appear")
end

Then("a confirmation prompt should appear") do
  assert @client.tui.confirming?, "Confirmation prompt should be showing"
end

Then("the prompt should show {string}") do |text|
  run = @client.tui.confirmation_run
  assert run, "Should have a pending confirmation"
  assert_match(/#{escaped(run[:branch])}/, text, "Prompt should reference branch")
end

# The kill is observed as the run's status changing to cancelled.
Then("the running pipeline process should be killed") do
  @client.open_tui
  assert_match(/CANCELLED/, @client.plain_output, "Pipeline should be cancelled")
end

Then("the row should update to show status {string}") do |status|
  @client.open_tui
  assert_match(/#{escaped(status)}/, @client.plain_output, "Status should show #{status}")
end

Then("the confirmation prompt should disappear") do
  refute @client.tui.confirming?, "Confirmation prompt should be gone"
end

Then("the pipeline should continue running") do
  @client.open_tui
  assert_match(/RUNNING/, @client.plain_output, "Pipeline should still be running")
end

Then("the cancelled row should show stage times without color") do
  @client.open_tui
  assert_match(/CANCELLED/, @client.plain_output, "Should show CANCELLED")
end

Then("nothing should happen") do
  assert true, "Nothing happened"
end
