# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/console/board_data"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
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
    board = FunCi::Console::BoardData.new(@db)
    result = board.runs
    assert_empty result, "Should return empty array for empty database"
  end

  def test_should_return_runs_with_stage_data
    create_completed_run("abc1234", "main")
    board = FunCi::Console::BoardData.new(@db)
    result = board.runs
    assert_equal 1, result.length
    assert_equal "abc1234", result[0][:commit_hash]
    assert_equal 4, result[0][:stages].length, "Should have 4 stages"
  end

  def test_should_calculate_stage_durations
    create_completed_run("abc1234", "main")
    stages = FunCi::Console::BoardData.new(@db).runs[0][:stages]
    durations = stages.select { |s| s[:status] == "completed" }.map { |s| s[:duration] }

    assert_equal 4, durations.size, "the fixture's four stages should all be completed"
    refute_includes durations, nil
  end

  # The milestones' order comes from the order the stages finished in.
  def test_should_give_each_stage_the_order_it_finished_in
    create_completed_run("abc1234", "main")
    slow = FunCi::Console::BoardData.new(@db).runs[0][:stages].last

    assert_equal 4, slow[:finished_order], "the fixture finishes lint, build, fast, then slow"
  end

  def test_should_return_runs_in_reverse_chronological_order
    create_completed_run("first11", "main")
    create_completed_run("second2", "main")
    board = FunCi::Console::BoardData.new(@db)
    result = board.runs
    assert_equal "second2", result[0][:commit_hash]
    assert_equal "first11", result[1][:commit_hash]
  end

  def test_should_limit_to_specified_count
    5.times { |i| create_completed_run("hash#{i.to_s.rjust(3, "0")}", "main") }
    board = FunCi::Console::BoardData.new(@db, limit: 3)
    result = board.runs
    assert_equal 3, result.length, "Should limit to 3 runs"
  end

  def test_should_compute_streak
    3.times { |i| create_completed_run("pass#{i.to_s.rjust(3, "0")}", "main") }
    board = FunCi::Console::BoardData.new(@db)
    result = board.streak
    assert_equal 3, result
  end

  def test_should_use_page_size_as_initial_limit
    10.times { |i| create_completed_run("hash#{format("%02d", i)}", "main") }
    board = FunCi::Console::BoardData.new(@db, page_size: 3)
    result = board.runs
    assert_equal 3, result.length, "Should initially show page_size rows"
  end

  def test_should_show_more_after_load_more
    10.times { |i| create_completed_run("hash#{format("%02d", i)}", "main") }
    board = FunCi::Console::BoardData.new(@db, page_size: 3)
    board.load_more
    result = board.runs
    assert_equal 6, result.length, "Should show 2 pages after load_more"
  end

  def test_should_not_exceed_total_runs_after_load_more
    5.times { |i| create_completed_run("hash#{format("%02d", i)}", "main") }
    board = FunCi::Console::BoardData.new(@db, page_size: 3)
    board.load_more
    board.load_more
    result = board.runs
    assert_equal 5, result.length, "Should not exceed total runs"
  end

  def test_should_cancel_a_run
    run_id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc1234", branch: "main")
    board = FunCi::Console::BoardData.new(@db)
    board.cancel_run(run_id)
    run = board.runs.find { |r| r[:id] == run_id }
    assert_equal "cancelled", run[:status]
  end
end
