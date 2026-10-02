# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require_relative "agent_client"
require "fun_ci/persistence/job_runs"

# `fun-ci events` tells of a job waiting its turn to start (Jobs::Schedule,
# AT-13.28): that it was scheduled, and when it starts, then that it started.
class TestAgentEventsJobsScheduled < Minitest::Test
  SHA = "9e0b1d4a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4"
  WAITING = JobRecording::JobRunFacts.new(status: "scheduled", ago: -480, seconds: nil)

  def setup
    @client = AgentClient.open
    @client.add_job("soak", "weekly")
    @id = @client.record_job_run("soak", SHA, WAITING)
  end

  def teardown = @client.close

  def test_should_say_a_job_was_scheduled_and_when_it_starts
    @client.events

    assert_equal({ "schema" => 1, "event" => "job_scheduled", "job" => "soak", "cadence" => "weekly", "commit" => SHA,
                   "branch" => "main", "starts_at" => (@client.clock.now + 480).utc.iso8601 }, events.first)
  end

  def test_should_not_say_a_job_waiting_its_turn_started
    @client.events

    assert_equal ["job_scheduled"], names
  end

  def test_should_say_a_waiting_job_started_once_its_turn_came
    @client.clock.then_do { FunCi::Persistence::JobRuns.new(@client.db, @client.job_project).start_turn(@id, Time.now) }
    @client.clock.then_do { raise Interrupt }
    @client.events("--follow")

    assert_equal %w[job_scheduled job_started], names
  end

  private

  def events = @client.stdout.lines.map { |line| JSON.parse(line) }
  def names = events.map { |event| event["event"] }
end
