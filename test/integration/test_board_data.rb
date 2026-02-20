# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/board_data"
require "fun_ci/database"
require "fun_ci/pipeline_run"
require "fun_ci/stage_job"
require "tmpdir"

class TestBoardData < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
  end

  def teardown
    teardown_test_db
  end

  def test_should_return_empty_array_when_no_runs
    # Given an empty database
    board = FunCi::BoardData.new(@db)
    # When we fetch runs
    result = board.runs
    # Then it should be empty
    assert_empty result, "Should return empty array for empty database"
  end

  def test_should_return_runs_with_stage_data
    # Given a pipeline run with stage jobs
    create_completed_run("abc1234", "main")
    board = FunCi::BoardData.new(@db)
    # When we fetch runs
    result = board.runs
    # Then the run should have stages attached
    assert_equal 1, result.length
    assert_equal "abc1234", result[0][:commit_hash]
    assert_equal 4, result[0][:stages].length, "Should have 4 stages"
  end

  def test_should_calculate_stage_durations
    # Given a completed run with known start/end times
    create_completed_run("abc1234", "main")
    board = FunCi::BoardData.new(@db)
    result = board.runs
    stages = result[0][:stages]
    # Then each completed stage should have a duration
    stages.select { |s| s[:status] == "completed" }.each do |stage|
      refute_nil stage[:duration], "Completed stages should have duration"
    end
  end

  def test_should_return_runs_in_reverse_chronological_order
    # Given multiple runs
    create_completed_run("first11", "main")
    create_completed_run("second2", "main")
    board = FunCi::BoardData.new(@db)
    result = board.runs
    # Then most recent should be first
    assert_equal "second2", result[0][:commit_hash]
    assert_equal "first11", result[1][:commit_hash]
  end

  def test_should_limit_to_specified_count
    # Given many runs
    5.times { |i| create_completed_run("hash#{i.to_s.rjust(3, "0")}", "main") }
    board = FunCi::BoardData.new(@db, limit: 3)
    result = board.runs
    assert_equal 3, result.length, "Should limit to 3 runs"
  end

  def test_should_compute_streak
    # Given 3 consecutive completed runs
    3.times { |i| create_completed_run("pass#{i.to_s.rjust(3, "0")}", "main") }
    board = FunCi::BoardData.new(@db)
    result = board.streak
    assert_equal 3, result
  end

  def test_should_cancel_a_run
    run_id = FunCi::PipelineRun.create(@db, commit_hash: "abc1234", branch: "main")
    board = FunCi::BoardData.new(@db)
    board.cancel_run(run_id)
    run = board.runs.find { |r| r[:id] == run_id }
    assert_equal "cancelled", run[:status]
  end

end
