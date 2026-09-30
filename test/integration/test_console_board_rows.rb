# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/console/board_data"
require "fun_ci/console/console_state"
require "fun_ci/console/key_handler"
require "fun_ci/console/view"
require "fun_ci/persistence/database"

# AT-12.1: the console's board has one row per branch, the branch's newest
# run, so the table reads as where each branch stands.
class TestConsoleBoardRows < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
    board_data = FunCi::Console::BoardData.new(@db)
    view = FunCi::Console::View.new(key_handler: FunCi::Console::KeyHandler.new(board_data: board_data))
    @console = FunCi::Console::ConsoleState.new(board_data: board_data, view: view, clock: -> { Time.now })
    @console.resize(40)
  end

  def teardown
    teardown_test_db
  end

  def test_should_show_only_the_newest_run_of_a_branch_run_more_than_once
    create_completed_run("old", "main")
    create_failed_run("new", "main")

    assert_equal(["new"], board_runs.map { |run| run[:sha] })
  end

  private

  def board_runs = @console.updates.last[:runs]
end
