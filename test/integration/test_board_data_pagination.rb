# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/console/board_data"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "tmpdir"

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
    10.times { |i| create_completed_run("hash#{format("%02d", i)}", "main") }
    board = FunCi::Console::BoardData.new(@db, limit: 5)
    result = board.runs

    assert_equal 5, result.size, "Should respect initial limit"
  end

  def test_should_show_more_runs_after_load_more
    10.times { |i| create_completed_run("hash#{format("%02d", i)}", "main") }
    board = FunCi::Console::BoardData.new(@db, limit: 5)
    board.load_more

    result = board.runs
    assert_equal 10, result.size,
                 "Should show 10 runs after one load_more"
  end

  def test_should_not_exceed_total_available_runs
    7.times { |i| create_completed_run("hash#{format("%02d", i)}", "main") }
    board = FunCi::Console::BoardData.new(@db, limit: 5)
    board.load_more
    board.load_more
    result = board.runs
    assert_equal 7, result.size,
                 "Should not exceed total available runs"
  end

  def test_should_load_a_page_of_the_new_size_once_resized
    board = board_over(10, page_size: 3)
    board.resize(5)

    assert_equal 5, board.runs.size
  end

  def test_should_load_pages_of_the_new_size_after_a_resize
    board = board_over(10, page_size: 3)
    board.resize(4)
    board.load_more

    assert_equal 8, board.runs.size
  end

  def test_should_keep_what_it_loaded_when_resized_smaller
    board = board_over(10, page_size: 5)
    board.resize(3)

    assert_equal 5, board.runs.size
  end

  def test_should_report_more_when_the_store_holds_runs_beyond_those_loaded
    assert_predicate board_over(4, page_size: 3), :more?
  end

  def test_should_report_no_more_when_every_run_is_loaded
    refute_predicate board_over(3, page_size: 3), :more?
  end

  private

  def board_over(count, page_size:)
    count.times { |i| create_completed_run("hash#{format("%02d", i)}", "main") }
    FunCi::Console::BoardData.new(@db, page_size: page_size)
  end
end
