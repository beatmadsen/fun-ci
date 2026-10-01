# frozen_string_literal: true

require_relative "../test_helper"
require_relative "agent_client"

# `fun-ci cancel --job NAME` stops a daily or weekly job's running run, as
# `c` on its row in the console does, so it is due again on the next commit
# rather than failed (acceptance-tests.md, AT-13.26).
class TestAgentCancelJob < Minitest::Test
  SHA = "9e0b1d4a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4"
  RUNNING = JobRecording::JobRunFacts.new(status: "running")
  PASSED = JobRecording::JobRunFacts.new(status: "completed", exit_status: 0)

  def setup
    @agent = AgentClient.open
    @agent.add_job("mutation", "daily")
    @agent.add_job("soak", "weekly")
  end

  def teardown = @agent.close

  def test_should_cancel_the_running_run_of_the_job_named
    run = @agent.record_job_run("mutation", SHA, RUNNING)
    @agent.record_job_run("soak", SHA, RUNNING)
    @agent.cancel("--job", "mutation")

    assert_equal [run], @agent.pipeline.cancelled_jobs
  end

  def test_should_say_the_job_runs_again_on_the_next_commit
    @agent.record_job_run("mutation", SHA, RUNNING)
    @agent.cancel("--job", "mutation")

    assert_equal "fun-ci: cancelled job mutation; it runs again on the next commit.\n", @agent.stdout
  end

  def test_should_succeed_once_the_job_is_cancelled
    @agent.record_job_run("mutation", SHA, RUNNING)

    assert_equal 0, @agent.cancel("--job", "mutation")
  end

  def test_should_say_a_job_that_is_not_running_has_nothing_to_cancel
    @agent.record_job_run("mutation", SHA, PASSED)
    @agent.cancel("--job", "mutation")

    assert_equal "fun-ci: job mutation is not running, so there is nothing to cancel.\n", @agent.stdout
  end

  def test_should_refuse_a_name_that_is_no_job_of_the_project
    assert_equal 64, @agent.cancel("--job", "fuzz")
  end

  def test_should_refuse_to_cancel_without_a_job_named
    assert_equal 64, @agent.cancel
  end
end
