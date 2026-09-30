# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/console/board_data"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "tmpdir"

# A branch whose newest runs were cancelled one after another shows as one
# row that says how many it stands for (CancelledFolding decides what folds).
class TestBoardDataFolding < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
    3.times { |i| create_completed_run("main#{i}", "main") }
    5.times { |i| create_pipeline_run("rebase#{i}", "detached", "cancelled") }
    @board = FunCi::Console::BoardData.new(@db, page_size: 3)
  end

  def teardown
    teardown_test_db
  end

  def test_should_fold_a_branch_s_consecutive_cancelled_runs_into_one_row
    assert_equal 5, @board.runs.first[:folded]
  end

  def test_should_show_the_other_branches_after_the_folded_one
    branches = @board.runs.map { |run| run[:branch] }

    assert_equal %w[detached main], branches
  end
end
