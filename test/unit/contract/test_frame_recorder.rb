# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../contract/capture/frame_recorder"

class TestFrameRecorder < Minitest::Test
  NOW = 1_790_000_000
  TICK = { "t" => "tick", "ms" => 100 }.freeze
  RUNNING = { "id" => 1, "sha" => "a3f7c01" + ("0" * 33), "branch" => "main", "status" => "running",
              "updated_at" => NOW, "stages" => [
                { "stage" => "fast", "status" => "running", "started_at" => NOW - 9 }
              ] }.freeze
  SCENARIO = [{ "t" => "resize", "cols" => 80, "rows" => 30 },
              { "t" => "board", "now" => NOW, "streak" => 0, "cursor" => 0,
                "confirming" => false, "runs" => [RUNNING] },
              TICK, TICK].freeze

  def test_each_tick_draws_one_frame_and_nothing_else_does
    assert_equal 2, replay(SCENARIO).size
  end

  def test_the_first_frame_starts_by_clearing_the_screen
    assert replay(SCENARIO).first.start_with?("\e[2J\e[H")
  end

  def test_elapsed_time_comes_from_the_scenario_clock
    frames = replay(SCENARIO[0..1] + Array.new(10, TICK))

    assert_equal ["9s", "10s"], [frames[8], frames[9]].map { |f| f[/Fast \S+ (\d+s)/, 1] }
  end

  def test_a_frame_holds_only_the_bytes_of_its_own_tick
    emptied = SCENARIO[1].merge("runs" => [])
    frames = replay(SCENARIO[0..2] + [emptied, TICK])

    refute_includes frames.last, "a3f7c01"
  end

  def test_two_recorders_draw_identical_bytes
    assert_equal replay(SCENARIO), replay(SCENARIO)
  end

  def test_frames_are_binary_so_they_compare_equal_to_files_read_back
    assert_equal Encoding::BINARY, replay(SCENARIO).first.encoding
  end

  private

  def replay(messages)
    FunCi::Contract::FrameRecorder.build.replay(messages)
  end
end
