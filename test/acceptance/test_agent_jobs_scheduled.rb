# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require_relative "agent_client"

# A job waiting its turn to start (Jobs::Schedule) is shown with when it
# starts, by every command that names jobs (acceptance-tests.md, AT-13.28).
class TestAgentJobsScheduled < Minitest::Test
  SHA = "9e0b1d4a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4"
  # It starts in eight minutes: its run's start is ahead of the clock.
  WAITING = JobRecording::JobRunFacts.new(status: "scheduled", ago: -480, seconds: nil)
  PASSED = { "lint" => "completed", "build" => "completed", "fast" => "completed", "slow" => "completed" }.freeze

  def setup
    @agent = AgentClient.open
    @agent.git.commit(SHA, "Add a soak test")
    @agent.add_job("soak", "weekly")
    @agent.record_job_run("soak", SHA, WAITING)
  end

  def teardown = @agent.close

  def test_should_say_in_the_jobs_list_when_a_waiting_job_starts
    @agent.jobs

    assert_equal "soak  weekly  wait          main 9e0b1d4  starts in 8m", @agent.stdout.lines.first.chomp
  end

  def test_should_say_a_waiting_job_is_scheduled_in_the_jobs_json
    @agent.jobs("--json")

    assert_equal "scheduled", job_json["state"]
  end

  def test_should_give_when_a_waiting_job_starts_in_the_jobs_json
    @agent.jobs("--json")

    assert_equal (@agent.clock.now + 480).utc.iso8601, job_json["starts_at"]
  end

  def test_should_say_in_status_when_a_waiting_job_on_the_commit_starts
    @agent.record_run(SHA, stages: PASSED)
    @agent.status

    assert_includes @agent.stdout, "  soak (weekly job) scheduled, starts in 8m\n"
  end

  def test_should_say_in_why_when_a_waiting_job_starts_and_how_to_cancel_it
    @agent.why("--job", "soak")

    assert_includes @agent.stdout, "It waits its turn, and starts in 8m; fun-ci cancel --job soak cancels it.\n"
  end

  def test_should_exit_undecided_from_why_for_a_waiting_job
    assert_equal 3, @agent.why("--job", "soak")
  end

  private

  def job_json = JSON.parse(@agent.stdout)["jobs"].first
end
