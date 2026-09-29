# frozen_string_literal: true

require_relative "../test_helper"
require "yaml"

# AT-0.7: CI runs the gate on every supported Ruby, on every push. The
# mutation lanes run nightly instead (test_mutation_workflow.rb).
class TestCiWorkflow < Minitest::Test
  WORKFLOW = File.expand_path("../../.github/workflows/ci.yml", __dir__)

  def test_the_gate_runs_on_every_supported_ruby
    assert_equal %w[3.2 3.3 3.4 4.0], jobs.dig("gate", "strategy", "matrix", "ruby")
  end

  def test_one_ruby_failing_does_not_cancel_the_others
    assert_equal false, jobs.dig("gate", "strategy", "fail-fast")
  end

  def test_the_gate_job_runs_the_default_rake_task
    assert_includes commands("gate"), "bundle exec rake"
  end

  def test_a_newer_push_cancels_the_gate_it_supersedes
    assert_equal true, jobs.dig("gate", "concurrency", "cancel-in-progress")
  end

  def test_the_gate_installs_the_pinned_rust
    assert_includes commands("gate"), "rustup toolchain install"
  end

  def test_no_mutation_lane_runs_on_a_push
    assert_empty jobs.keys.grep(/mutation/)
  end

  def test_no_job_installs_whichever_rust_is_latest
    refute_includes steps_used, "dtolnay/rust-toolchain@stable"
  end

  def test_ci_runs_on_pushes_to_main
    assert_includes workflow.dig(true, "push", "branches"), "main"
  end

  def test_ci_runs_on_pull_requests
    assert workflow.fetch(true).key?("pull_request")
  end

  private

  # YAML 1.1 reads the key `on` as true.
  def workflow = YAML.safe_load_file(WORKFLOW)
  def jobs = workflow.fetch("jobs")
  def commands(job) = jobs.dig(job, "steps").filter_map { |step| step["run"] }
  def steps_used = jobs.values.flat_map { |job| job["steps"].filter_map { |step| step["uses"] } }
end
