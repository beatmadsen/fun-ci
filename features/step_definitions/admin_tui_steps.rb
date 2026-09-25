# frozen_string_literal: true

# Given steps that put a single pipeline run, with its stages, on the board.

Given("a pipeline run for commit {string} on branch {string} has completed") do |commit, branch|
  @client.create_pipeline_run(commit: commit, branch: branch, status: "completed")
end

Given("the build stage passed in {float} seconds") do |seconds|
  @client.add_stage(stage: "build", status: "completed", duration: seconds)
end

Given("the fast suite passed in {float} seconds") do |seconds|
  @client.add_stage(stage: "fast", status: "completed", duration: seconds)
end

Given("the slow suite passed in {int} seconds") do |seconds|
  @client.add_stage(stage: "slow", status: "completed", duration: seconds.to_f)
end

Given("a pipeline run for commit {string} on branch {string} completed {int} minutes ago") do |commit, branch, minutes|
  @client.create_full_passed_run(commit: commit, branch: branch, minutes_ago: minutes)
end

Given("a pipeline run for commit {string} on branch {string} has failed") do |commit, branch|
  @client.create_pipeline_run(commit: commit, branch: branch, status: "failed")
end

Given("the fast suite failed at {float} seconds") do |seconds|
  @client.add_stage(stage: "fast", status: "failed", duration: seconds)
end

Given("a pipeline run where the fast suite failed") do
  create_run_with_stages("abc1234", "test", "failed",
                         build: ["completed", 0.1], fast: ["failed", 6.2], slow: ["scheduled"])
end

Given("a pipeline run for commit {string} on branch {string} has timed out") do |commit, branch|
  @client.create_pipeline_run(commit: commit, branch: branch, status: "timed_out")
end

Given("the fast suite timed out at {int} seconds") do |seconds|
  @client.add_stage(stage: "fast", status: "timed_out", duration: seconds.to_f)
end

Given("a pipeline run for commit {string} on branch {string} is scheduled") do |commit, branch|
  @client.create_pipeline_run(commit: commit, branch: branch, status: "scheduled")
end

Given("a pipeline run for commit {string} on branch {string} was cancelled") do |commit, branch|
  create_run_with_stages(commit, branch, "cancelled",
                         build: ["completed", 0.2], fast: ["cancelled", 7.0], slow: ["scheduled"])
end

Given("a pipeline run that passed all stages") do
  @client.create_full_passed_run(commit: "abc1234", branch: "main")
end

Given("a completed pipeline run exists") do
  @client.create_full_passed_run(commit: "abc1234", branch: "main")
end

Given("a pipeline run where the fast suite timed out") do
  create_run_with_stages("def5678", "test", "timed_out",
                         build: ["completed", 0.2], fast: ["timed_out", 10.0], slow: ["scheduled"])
end

Given("a pipeline run currently in the slow suite stage") do
  create_run_with_stages("run1234", "feat/parser", "running",
                         build: ["completed", 0.2], fast: ["completed", 2.4], slow: ["running", 34])
end

Given("a pipeline run currently in the fast suite stage") do
  create_running_run("run1234", "feat/parser", fast_seconds: 3)
end

Given("a pipeline run currently in the fast suite stage at {int} seconds elapsed") do |seconds|
  create_running_run("run1234", "feat/parser", fast_seconds: seconds)
end

Given("a pipeline run that is scheduled but not yet started") do
  @client.create_pipeline_run(commit: "sched12", branch: "feat/cache", status: "scheduled")
end

Given("any pipeline run on the board") do
  @client.create_full_passed_run(commit: "any1234", branch: "main")
end

Given("a pipeline run that was cancelled") do
  create_run_with_stages("canc123", "feat/old", "cancelled",
                         build: ["completed", 0.2], fast: ["cancelled", 7.0], slow: ["scheduled"])
end

Given("a pipeline run where the fast suite is active") do
  create_running_run("act1234", "feat/active", fast_seconds: 3)
end

Given("a pipeline run for commit {string} on branch {string} is running") do |commit, branch|
  create_running_run(commit, branch, fast_seconds: 7)
end

Given("a new pipeline run is currently running") do
  create_running_run("run9999", "feat/new", fast_seconds: 3)
end

Given("a pipeline run is currently running") do
  create_running_run("run1234", "feat/test", fast_seconds: 3)
end

Given("a pipeline run is currently running on the board") do
  create_running_run("run1234", "feat/test", fast_seconds: 3)
  @client.open_tui
end
