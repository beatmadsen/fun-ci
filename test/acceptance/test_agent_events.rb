# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require_relative "agent_client"

# `fun-ci events` prints what happens as JSON lines (acceptance-tests.md,
# AT-9.16): the project's recent runs' events, then, with --follow, each new
# one as it happens, until interrupted.
class TestAgentEvents < Minitest::Test
  OLD = "aaa1111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  NEW = "bbb2222bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

  def setup
    @client = AgentClient.open
    @client.git.commit(OLD, "Old work")
    @client.git.commit(NEW, "New work")
  end

  def teardown = @client.close

  def test_should_print_the_events_of_the_project_s_recent_runs
    @client.record_run(OLD, stages: { "lint" => "completed", "build" => "failed" })

    @client.events

    assert_equal [%w[run_started], %w[stage_finished lint passed], %w[stage_finished build failed]], summary
  end

  def test_should_name_the_commit_and_branch_on_each_line_with_a_schema
    @client.record_run(OLD)

    @client.events

    assert_equal({ "schema" => 1, "event" => "run_started", "commit" => OLD, "branch" => "main" }, events.first)
  end

  def test_should_print_each_new_event_as_it_happens_when_following
    run = @client.record_run(OLD, stages: { "lint" => "completed" })
    @client.clock.then_do { @client.finish_stage(run, "build", "timed_out") }
    @client.clock.then_do { raise Interrupt }

    assert_equal [0, %w[stage_finished build over_budget]], [@client.events("--follow"), summary.last]
  end

  def test_should_say_when_a_run_is_superseded_and_by_which_commit
    run = @client.record_run(OLD)
    @client.clock.then_do { supersede(run, by: NEW) }
    @client.clock.then_do { raise Interrupt }
    @client.events("--follow")

    assert_includes events, { "schema" => 1, "event" => "run_superseded", "commit" => OLD, "branch" => "main",
                              "by_commit" => NEW }
  end

  def test_should_say_when_a_run_finishes
    run = @client.record_run(OLD)
    @client.clock.then_do { FunCi::Persistence::PipelineRun.update_status(@client.db, run, "completed") }
    @client.clock.then_do { raise Interrupt }
    @client.events("--follow")

    assert_equal %w[run_finished passed], summary.last
  end

  def test_should_print_only_failures_when_asked
    @client.record_run(OLD, stages: { "lint" => "completed", "build" => "failed" })

    @client.events("--only", "failures")

    assert_equal [%w[stage_finished build failed]], summary
  end

  def test_should_leave_out_other_projects_runs
    @client.record_run(OLD, project: "/another/project")

    @client.events

    assert_empty @client.stdout
  end

  def test_should_look_for_slow_suites_that_died_each_time_it_looks_again
    2.times { @client.clock.then_do { nil } }
    @client.clock.then_do { raise Interrupt }
    @client.events("--follow")

    assert_equal 2, @client.pipeline.watched
  end

  private

  def supersede(run, by:)
    FunCi::Persistence::PipelineRun.update_status(@client.db, run, "cancelled")
    @client.record_run(by)
  end

  def events = @client.stdout.lines.map { |line| JSON.parse(line) }
  def summary = events.map { |event| event.values_at("event", "stage", "state").compact }
end
