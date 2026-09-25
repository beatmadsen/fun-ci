# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/board_data"
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
    board = FunCi::Tui::BoardData.new(@db, limit: 5)
    result = board.runs

    assert_equal 5, result.size, "Should respect initial limit"
  end

  def test_should_show_more_runs_after_load_more
    10.times { |i| create_completed_run("hash#{format("%02d", i)}", "main") }
    board = FunCi::Tui::BoardData.new(@db, limit: 5)
    board.load_more

    result = board.runs
    assert_equal 10, result.size,
                 "Should show 10 runs after one load_more"
  end

  def test_should_not_exceed_total_available_runs
    7.times { |i| create_completed_run("hash#{format("%02d", i)}", "main") }
    board = FunCi::Tui::BoardData.new(@db, limit: 5)
    board.load_more
    board.load_more
    result = board.runs
    assert_equal 7, result.size,
                 "Should not exceed total available runs"
  end
end
