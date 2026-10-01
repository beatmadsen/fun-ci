# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require "time"
require_relative "agent_client"

# `fun-ci jobs --json`: the project's jobs as one document (acceptance-tests.md, AT-13.22).
class TestAgentJobsJson < Minitest::Test
  SHA = "9e0b1d4a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4"
  FAILED = JobRecording::JobRunFacts.new(status: "failed", exit_status: 1, ago: 3600, seconds: 2)
  PASSED = JobRecording::JobRunFacts.new(status: "completed", exit_status: 0, ago: 7200, seconds: 42)
  # Its process died before it said how the run ended: failed, with no end.
  LOST = JobRecording::JobRunFacts.new(status: "failed", seconds: nil)
  CANCELLED = JobRecording::JobRunFacts.new(status: "cancelled")

  def setup
    @agent = AgentClient.open
    @agent.add_job("soak", "weekly")
    @agent.add_job("mutation", "daily")
  end

  def teardown = @agent.close

  def test_should_say_a_cancelled_job_was_cancelled_as_json
    @agent.record_job_run("soak", SHA, CANCELLED)
    @agent.jobs("--json")

    assert_equal "cancelled", job_json("soak")["state"]
  end

  def test_should_say_a_cancelled_job_is_due_as_json
    @agent.record_job_run("soak", SHA, CANCELLED)
    @agent.jobs("--json")

    assert_equal true, job_json("soak")["due"]
  end

  def test_should_give_each_job_as_json
    @agent.record_job_run("soak", SHA, FAILED, branch: "wip/foo")
    @agent.jobs("--json")

    assert_equal({ "cadence" => "weekly", "state" => "failed", "commit" => { "sha" => SHA, "branch" => "wip/foo" },
                   "seconds" => 2.0 }, job_json("soak").slice("cadence", "state", "commit", "seconds"))
  end

  def test_should_say_a_weekly_job_is_due_a_week_after_its_run_started_as_json
    @agent.record_job_run("soak", SHA, FAILED)
    @agent.jobs("--json")

    assert_equal 7 * 86_400, Time.parse(job_json("soak")["due_at"]) - Time.parse(job_json("soak")["started_at"])
  end

  def test_should_say_a_job_that_ran_within_its_period_is_not_due_as_json
    @agent.record_job_run("mutation", SHA, PASSED)
    @agent.jobs("--json")

    assert_equal false, job_json("mutation")["due"]
  end

  def test_should_say_a_lost_job_is_lost_as_json
    @agent.record_job_run("soak", SHA, LOST)
    @agent.jobs("--json")

    assert_equal "lost", job_json("soak")["state"]
  end

  private

  def job_json(name) = JSON.parse(@agent.stdout)["jobs"].find { |job| job["name"] == name }
end
