# frozen_string_literal: true

# Then steps about running pipelines: spinners, elapsed time, live refresh.

Then("the fast suite stage should display a braille spinner") do
  assert_match(AdminTuiStepHelpers::BRAILLE, @client.plain_output, "Should display a braille spinner")
end

# Eight refreshes show the eight frames once each, the ninth starts the cycle again,
# and the loop waits about 100ms between them.
Then("the spinner should cycle through its frames at approximately 100ms") do
  glyphs = Array.new(9) { spinner_glyph_after_refresh("Fast") }
  assert_equal 8, glyphs.first(8).uniq.length, "Eight refreshes should show eight frames: #{glyphs.inspect}"
  assert_equal glyphs.first, glyphs.last, "The ninth refresh should start the cycle again"
  assert_in_delta 0.1, @client.refresh_interval, 0.01, "Frames should be about 100ms apart"
end

Then("the elapsed time should increment from {int}s to {int}s") do |from, to|
  assert_match(/Fast \S #{from}s/, @client.previous_plain_output, "Before, the fast suite should show #{from}s")
  assert_match(/Fast \S #{to}s/, @client.plain_output, "After, the fast suite should show #{to}s")
end

Then("the build stage should show {string} in green without a spinner") do |text|
  assert_stage_green_without_spinner("Build", text)
end

Then("the fast suite should show {string} in green without a spinner") do |text|
  assert_stage_green_without_spinner("Fast", text)
end

Then("the slow suite should show a spinner with elapsed time in cyan") do
  assert_match(/\e\[36mSlow #{AdminTuiStepHelpers::BRAILLE} \d+s\e\[0m/, raw_row("RUNNING"),
               "Slow suite should show a spinner and elapsed seconds, in cyan")
end

Then("the running row should have no background highlight") do
  row = raw_row("RUNNING")
  assert row, "Should show a RUNNING row"
  refute(sgr_codes(row).any? { |code| code.match?(/\A(4\d|10\d)(;|\z)/) }, "No background colour on #{row.inspect}")
end

# A spinner animates: its glyph changes from one refresh to the next on every running row.
Then("each running pipeline should show a spinner") do
  before = running_row_glyphs
  @client.refresh
  after = running_row_glyphs
  assert_equal 2, before.length, "Both running rows should show an active stage: #{@client.plain_output}"
  before.zip(after).each { |(was, now)| refute_equal was, now, "Each running row's spinner should advance" }
end

Then("the board should refresh approximately every {float} second(s)") do |seconds|
  assert_in_delta seconds, @client.refresh_interval, seconds / 10, "The loop should wait about #{seconds}s"
end

Then("the row should update from {string} to {string} in place") do |from, to|
  index = @client.previous_plain_output.lines.index { |line| line.include?(from) }
  assert index, "Before, the board should show a #{from} row"
  commit = row_commit(@client.previous_plain_output.lines[index])
  assert_match(/#{commit}.*#{escaped(to)}/, @client.board_lines[index], "The same line should now show #{to}")
end

# The frame starts by moving the cursor home and never clears the screen.
Then("no full screen redraw should occur") do
  assert @client.raw_output.start_with?("\e[H"), "The frame should be drawn over the last one from the top"
  refute_includes @client.raw_output, "\e[2J", "The frame should not clear the screen"
end

# The loop is waiting on the settled interval when the run begins; that wait ends in a refresh.
Then("the refresh cadence should switch to approximately every {float} second(s)") do |seconds|
  assert_in_delta 5.0, @client.refresh_interval, 0.5, "Before the next refresh the loop is still on 5s"
  @client.refresh
  assert_in_delta seconds, @client.refresh_interval, seconds / 10, "After it, the loop should wait about #{seconds}s"
end
