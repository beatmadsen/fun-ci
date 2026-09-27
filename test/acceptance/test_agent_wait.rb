# frozen_string_literal: true

require_relative "../test_helper"
require_relative "agent_client"

# `fun-ci wait` waits for the level it needs (acceptance-tests.md, AT-9.9);
# each pause of the client's clock is a moment in which the run moves on.
class TestAgentWait < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"

  def setup
    @client = AgentClient.open
    @client.git.commit(SHA, "Add retry to fetch")
    @run = @client.record_run(SHA)
  end

  def teardown = @client.close

  def test_should_pass_as_soon_as_the_needed_stages_have_passed
    script(%w[lint completed], %w[build completed], %w[fast completed], %w[slow completed])

    assert_equal [0, 3], [@client.wait, @client.clock.pauses]
  end

  def test_should_fail_at_the_first_needed_stage_that_fails
    script(%w[lint failed], %w[build completed], %w[fast completed])

    assert_equal [1, 1], [@client.wait("--need", "all"), @client.clock.pauses]
  end

  def test_should_print_what_status_prints_once_decided
    script(%w[lint completed], %w[build completed], %w[fast completed])
    @client.wait

    assert_equal %(fun-ci: 3f9c2ab "Add retry to fetch" on main), @client.stdout.lines.first.chomp
  end

  def test_should_answer_at_once_for_a_run_already_decided
    %w[lint build fast].each { |stage| finish(stage, "completed") }

    assert_equal [0, 0], [@client.wait, @client.clock.pauses]
  end

  def test_should_give_up_undecided_at_the_agent_s_deadline
    finish("lint", "completed")

    assert_equal [3, 10], [@client.wait("--within", "10s"), @client.clock.pauses]
  end

  def test_should_look_for_slow_suites_that_died_each_time_it_polls
    script(%w[lint completed], %w[build completed], %w[fast completed])
    @client.wait

    assert_equal 4, @client.pipeline.watched
  end

  private

  # One stage finishes at each pause, in the order given.
  def script(*steps) = steps.each { |stage, outcome| @client.clock.then_do { finish(stage, outcome) } }

  def finish(stage, outcome)
    job = FunCi::Persistence::StageJob.create(@client.db, pipeline_run_id: @run, stage: stage)
    FunCi::Persistence::StageJob.update_status(@client.db, job, "running")
    FunCi::Persistence::StageJob.update_status(@client.db, job, outcome)
  end
end

# `wait` starts a run for a commit that has none (acceptance-tests.md, AT-9.11).
class TestAgentWaitStartsARun < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  PASSED_TO_FAST = { "lint" => "completed", "build" => "completed", "fast" => "completed" }.freeze

  def setup
    @client = AgentClient.open
    @client.git.commit(SHA, "Add retry to fetch")
  end

  def teardown = @client.close

  def test_should_start_a_run_on_the_current_branch_when_none_turns_up
    @client.wait("--within", "8")

    assert_equal [[SHA, "main"]], @client.pipeline.started
  end

  def test_should_give_the_post_commit_hook_s_run_five_seconds_to_turn_up
    @client.wait("--within", "4")

    assert_empty @client.pipeline.started
  end

  def test_should_start_a_run_once_five_seconds_have_passed_without_one
    @client.wait("--within", "5")

    assert_equal 1, @client.pipeline.started.size
  end

  def test_should_wait_on_a_run_that_turns_up_in_time_instead_of_starting_one
    4.times { @client.clock.then_do { nil } }
    @client.clock.then_do { @client.record_run(SHA, stages: PASSED_TO_FAST) }

    assert_equal [0, []], [@client.wait, @client.pipeline.started]
  end

  def test_should_stop_waiting_when_the_project_is_not_set_up_to_start_a_run
    @client.pipeline.set_up = false

    assert_equal [5, "fun-ci: no run for 3f9c2ab, and this project isn't set up to start one.\n"],
                 [@client.wait, @client.stdout]
  end

  def test_should_say_there_is_no_run_yet_when_none_turns_up_by_the_deadline
    assert_equal [3, "fun-ci: no run for 3f9c2ab yet.\n"], [@client.wait("--within", "8"), @client.stdout]
  end
end
