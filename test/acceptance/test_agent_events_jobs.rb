# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require_relative "agent_client"
require "fun_ci/persistence/job_recorder"

# `fun-ci events` tells of daily and weekly jobs too (acceptance-tests.md, AT-13.23).
class TestAgentEventsJobs < Minitest::Test
  SHA = "9e0b1d4a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4"
  RUNNING = JobRecording::JobRunFacts.new(status: "running")

  def setup
    @client = AgentClient.open
    @client.add_job("soak", "weekly")
  end

  def teardown = @client.close

  def test_should_say_a_job_started_naming_it_its_cadence_and_commit
    @client.record_job_run("soak", SHA, RUNNING, branch: "wip/foo")
    @client.events

    assert_equal({ "schema" => 1, "event" => "job_started", "job" => "soak", "cadence" => "weekly", "commit" => SHA,
                   "branch" => "wip/foo" }, events.first)
  end

  def test_should_say_a_job_finished_with_its_state_and_seconds
    @client.record_job_run("soak", SHA, JobRecording::JobRunFacts.new(status: "timed_out", seconds: 86_400))
    @client.events

    assert_equal [["job_finished", "over_budget", 86_400.0]], finished
  end

  def test_should_say_a_job_finished_as_it_happens_when_following
    id = @client.record_job_run("soak", SHA, RUNNING)
    @client.clock.then_do { FunCi::Persistence::JobRecorder.new(@client.db).end_stage(id, "failed") }
    @client.clock.then_do { raise Interrupt }
    @client.events("--follow")

    assert_equal([%w[job_finished failed]], finished.map { |event| event.first(2) })
  end

  def test_should_keep_a_failed_job_among_the_failures
    @client.record_job_run("soak", SHA, JobRecording::JobRunFacts.new(status: "failed"))
    @client.events("--only", "failures")

    assert_equal(%w[job_finished], events.map { |event| event["event"] })
  end

  def test_should_leave_a_passed_job_out_of_the_failures
    @client.record_job_run("soak", SHA, JobRecording::JobRunFacts.new(status: "completed"))
    @client.events("--only", "failures")

    assert_empty events
  end

  private

  def events = @client.stdout.lines.map { |line| JSON.parse(line) }

  def finished
    ended = events.select { |event| event["event"] == "job_finished" }
    ended.map { |event| event.values_at("event", "state", "seconds") }
  end
end
