# frozen_string_literal: true

# Steps that open the TUI, move the cursor and press keys.

Given("the cursor is on the first row") do
  open_tui_and_press("j")
end

Given("the cursor is on the second row") do
  open_tui_and_press("j", "j")
end

Given("the cursor is on the third row") do
  open_tui_and_press("j", "j", "j")
end

Given("the cursor is on that scheduled row") do
  open_tui_and_press("j")
end

Given("the cursor is on that running row") do
  open_tui_and_press("j")
end

Given("a confirmation prompt is showing for commit {string} on branch {string}") do |commit, branch|
  create_running_run(commit, branch, fast_seconds: 7)
  open_tui_and_press("j", "c")
end

Given("a running pipeline was just cancelled via confirmation") do
  create_running_run("canc456", "feat/old", fast_seconds: 7)
  open_tui_and_press("j", "c", "y")
end

Given("the cursor is on that completed row") do
  open_tui_and_press("j")
end

# The cursor is invisible by default.
Given("the cursor is invisible") do
  @client.open_tui
end

When("I open the admin TUI") do
  @client.open_tui
end

# Checks the render output rather than waiting in real time.
When("I watch the admin TUI for {int} seconds") do |_seconds|
  @client.open_tui
end

When("I press {string}") do |key|
  press_and_rerender(key)
end

When("I press the Down arrow key") do
  press_and_rerender(:down)
end

When("I press the Up arrow key") do
  press_and_rerender(:up)
end

When("I press Escape") do
  press_and_rerender(:escape)
end

When("the terminal is resized to width {int}") do |width|
  @client.simulate_resize(width)
end

When("the width provider starts returning {int}") do |width|
  @client.set_width_provider_value(width)
end

When("the TUI renders again") do
  @client.rerender
end

When("I look at the board") do
  @client.open_tui
end

When("the running pipeline completes successfully") do
  @client.complete_running_pipeline
  @client.open_tui
end

When("the running pipeline completes") do
  @client.open_tui
end

When("I watch the admin TUI") do
  @client.open_tui
end

When("a new pipeline run is triggered externally") do
  @client.create_full_passed_run(commit: "new1234", branch: "main")
end

When("a new pipeline run begins") do
  create_run_with_stages("new1234", "feat/new", "running",
                         build: ["running", 1], fast: ["scheduled"], slow: ["scheduled"])
end
