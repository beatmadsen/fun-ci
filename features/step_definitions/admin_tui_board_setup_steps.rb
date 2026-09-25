# frozen_string_literal: true

# Given steps that fill the board with several runs or set up the terminal.

Given("the following pipeline runs exist:") do |table|
  # Created in reverse so the most recent (lowest minutes_ago) gets the highest ID.
  table.hashes.reverse.each do |row|
    @client.create_full_passed_run(commit: row["commit"], branch: row["branch"], minutes_ago: row["completed_ago"].to_i)
  end
end

Given("{int} pipeline runs exist") do |count|
  create_passed_runs(count, "hash")
end

Given("the terminal height is {int} lines") do |_lines|
  # Terminal height is handled by the limit parameter in BoardData; the
  # row-count check is approximate instead.
end

Given("the TUI is open at terminal width {int}") do |width|
  @client.open_tui_at_width(width)
end

Given("the TUI is open with a width provider returning {int}") do |width|
  @client.open_tui_with_width_provider(width)
end

Given("two pipeline runs are both in a running state") do
  create_running_run("run0001", "feat/a", fast_seconds: 3, build_seconds: 0.1)
  create_running_run("run0002", "feat/b", fast_seconds: 5)
end

Given("pipeline runs exist on the board") do
  create_passed_runs(3, "nav", digits: 4)
end

Given("{int} pipeline runs exist on the board") do |count|
  create_passed_runs(count, "nav", digits: 4)
end

Given("the last {int} pipeline runs all passed consecutively") do |count|
  create_passed_runs(count, "pass")
end

Given("{int} pipeline runs passed and then {int} failed") do |passed, failed|
  create_passed_runs(passed, "pass")
  failed.times do |i|
    create_run_with_stages("fail#{i.to_s.rjust(3, "0")}", "main", "failed",
                           build: ["completed", 0.1], fast: ["failed", 5.0], slow: ["scheduled"])
  end
end

Given("{int} pipeline runs passed and then {int} timed out") do |passed, timed_out|
  create_passed_runs(passed, "pass")
  timed_out.times do |i|
    create_run_with_stages("tout#{i.to_s.rjust(3, "0")}", "main", "timed_out",
                           build: ["completed", 0.2], fast: ["timed_out", 10.0], slow: ["scheduled"])
  end
end

Given("the last {int} pipeline runs all passed") do |count|
  create_passed_runs(count, "pass")
end

Given("the streak is {string} and a pipeline is running") do |_streak_text|
  create_passed_runs(4, "pass")
  create_running_run("run9999", "feat/new", fast_seconds: 3)
end

Given("no pipeline runs have completed") do
  # Empty database, or only running and scheduled runs.
end

Given("only {int} pipeline run has passed") do |count|
  create_passed_runs(count, "solo")
end

Given("no pipeline runs exist") do
  # Empty database: nothing to create.
end

Given("all pipeline runs are completed") do
  create_passed_runs(3, "done")
end

Given("I am viewing the admin TUI with all runs completed") do
  create_passed_runs(3, "done")
  @client.open_tui
end

Given("all pipeline runs are completed and refresh is at 5 second cadence") do
  create_passed_runs(3, "done")
end
