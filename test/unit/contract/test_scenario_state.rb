# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../contract/capture/scenario_state"

class TestScenarioState < Minitest::Test
  NOW = 1_790_000_000
  RUN = { "id" => 1, "sha" => "a" * 40, "branch" => "main", "status" => "passed",
          "updated_at" => NOW, "stages" => [] }.freeze
  BOARD = { "t" => "board", "now" => NOW, "streak" => 3, "cursor" => 1,
            "confirming" => true, "runs" => [RUN] }.freeze

  def setup
    @state = FunCi::Contract::ScenarioState.new
  end

  def test_resize_sets_the_terminal_size
    @state.apply("t" => "resize", "cols" => 60, "rows" => 30)

    assert_equal [60, 30], [@state.cols, @state.rows]
  end

  def test_a_board_sets_the_clock_to_its_now
    @state.apply(BOARD)

    assert_equal Time.at(NOW), @state.board.now
  end

  def test_a_tick_advances_the_clock_by_exactly_its_milliseconds
    @state.apply(BOARD)
    3.times { @state.apply("t" => "tick", "ms" => 100) }

    assert_equal Time.at(NOW) + Rational(3, 10), @state.board.now
  end

  def test_a_later_board_resets_the_clock_to_its_own_now
    @state.apply(BOARD)
    @state.apply("t" => "tick", "ms" => 100)
    @state.apply(BOARD.merge("now" => NOW + 5))

    assert_equal Time.at(NOW + 5), @state.board.now
  end

  def test_the_board_carries_cursor_confirming_and_streak
    @state.apply(BOARD)

    assert_equal [1, true, 3], [@state.board.cursor_index, @state.board.confirming, @state.board.streak]
  end

  def test_the_board_runs_are_in_the_1x_shape
    @state.apply(BOARD)

    assert_equal "completed", @state.board.runs.first[:status]
  end

  def test_messages_that_only_the_renderer_acts_on_change_nothing
    @state.apply(BOARD)
    %w[hello event quit].each { |t| @state.apply("t" => t) }

    assert_equal [Time.at(NOW), 1], [@state.board.now, @state.board.runs.size]
  end
end
