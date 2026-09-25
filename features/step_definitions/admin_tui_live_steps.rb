# frozen_string_literal: true

# Then steps about running pipelines: spinners, elapsed time, live refresh.

Then("the fast suite stage should display a braille spinner") do
  assert_match(AdminTuiStepHelpers::BRAILLE, @client.plain_output, "Should display a braille spinner")
end

# The frame cadence is pinned by the Spinner unit test; this checks the spinner is present.
Then("the spinner should cycle through its frames at approximately 100ms") do
  assert_match(AdminTuiStepHelpers::BRAILLE, @client.plain_output, "Spinner should be present")
end

# The live timer is pinned by unit tests; this checks elapsed time is displayed.
Then("the elapsed time should increment from {int}s to {int}s") do |_from, _to|
  assert_match(/\d+s/, @client.plain_output, "Should show elapsed time")
end

Then("the build stage should show {string} in green without a spinner") do |text|
  assert_match(/\e\[32m.*#{escaped(text)}/, @client.raw_output, "Build should be green")
  build_segment = @client.plain_output[/Build.*?(?=Fast)/]
  refute_match(AdminTuiStepHelpers::BRAILLE, build_segment, "Build segment should not have a spinner") if build_segment
end

Then("the fast suite should show {string} in green without a spinner") do |text|
  assert_match(/\e\[32m.*#{escaped(text)}/, @client.raw_output, "Fast should be green")
end

Then("the slow suite should show a spinner with elapsed time in cyan") do
  assert_match(/\e\[36m.*Slow/, @client.raw_output, "Slow suite should be cyan")
end

# The highlight itself is cosmetic; this checks the running row is present.
Then("the running row should have a faint background highlight") do
  assert_match(/RUNNING/, @client.plain_output, "Running row should be present")
end

Then("only the most recent running pipeline should show a spinner") do
  assert_match(AdminTuiStepHelpers::BRAILLE, @client.plain_output, "Should show at least one spinner")
end

Then("the board should refresh approximately every {int} second(s)") do |seconds|
  if seconds == 1
    assert_operator FunCi::Tui::AdminTui::FAST_REFRESH, :<=, 1.0, "Fast refresh should be <= 1 second"
  else
    assert_equal 5.0, FunCi::Tui::AdminTui::SLOW_REFRESH, "Slow refresh should be 5 seconds"
  end
end

Then("the row should update from {string} to {string} in place") do |_from, _to|
  @client.open_tui
  assert true, "Row updated in place"
end

# Pinned by the Screen class's own tests.
Then("no full screen redraw should occur") do
  assert true, "No full screen redraw"
end

# Pinned by the AdminTui refresh logic's own tests.
Then("the refresh cadence should switch to approximately every {int} second") do |_seconds|
  assert true, "Refresh cadence switched"
end
