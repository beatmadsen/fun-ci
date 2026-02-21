# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/board_data"
require "fun_ci/database"
require "fun_ci/pipeline_run"
require "fun_ci/stage_job"
require "tmpdir"

# Inner BDD cycle: BoardData pagination support.
# BoardData should support load_more to increase visible limit.

class TestBoardDataPagination < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
  end

  def teardown
    teardown_test_db
  end

  def test_should_respect_initial_limit_as_page_size
    # Given 10 runs and a BoardData with limit 5
    10.times { |i| create_completed_run("hash#{format("%02d", i)}", "main") }
    board = FunCi::BoardData.new(@db, limit: 5)

    # When we fetch runs
    result = board.runs

    # Then only 5 should be returned
    assert_equal 5, result.size, "Should respect initial limit"
  end

  def test_should_show_more_runs_after_load_more
    # Given 10 runs and a BoardData with limit 5
    10.times { |i| create_completed_run("hash#{format("%02d", i)}", "main") }
    board = FunCi::BoardData.new(@db, limit: 5)

    # When we call load_more
    board.load_more

    # Then runs should return more (up to 10)
    result = board.runs
    assert_equal 10, result.size,
      "Should show 10 runs after one load_more"
  end

  def test_should_not_exceed_total_available_runs
    # Given 7 runs and a BoardData with limit 5
    7.times { |i| create_completed_run("hash#{format("%02d", i)}", "main") }
    board = FunCi::BoardData.new(@db, limit: 5)

    # When we call load_more twice
    board.load_more
    board.load_more

    # Then runs should be capped at 7 (not 15)
    result = board.runs
    assert_equal 7, result.size,
      "Should not exceed total available runs"
  end
end
