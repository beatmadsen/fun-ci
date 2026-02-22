# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/looping_animation_player"
require "fun_ci/tui/ansi"

class TestLoopingAnimationPlayerLifecycle < Minitest::Test
  def test_should_start_at_frame_zero
    player = make_player(frame_count: 3)
    assert_equal 0, player.frame
  end

  def test_should_advance_frame
    player = make_player(frame_count: 3)
    # When we advance once
    player.advance!
    # Then frame should be 1
    assert_equal 1, player.frame
  end

  def test_should_wrap_frame_after_reaching_total
    player = make_player(frame_count: 3)
    # When we advance past all frames
    3.times { player.advance! }
    # Then frame should wrap back to 0
    assert_equal 0, player.frame
  end

  def test_should_never_report_finished
    player = make_player(frame_count: 2)
    # When we advance many times past the total
    10.times { player.advance! }
    # Then it should never report finished
    refute player.finished?, "Looping player should never be finished"
  end

  def test_should_return_correct_frame_after_multiple_loops
    player = make_player(frame_count: 3)
    # When we advance through 3 full loops + 1 extra
    (3 * 3 + 1).times { player.advance! }
    # Then frame should be 1
    assert_equal 1, player.frame
  end

  def test_should_report_total_frames_from_data
    player = make_player(frame_count: 5)
    assert_equal 5, player.total_frames
  end

  private

  def make_player(frame_count:)
    frames = frame_count.times.map { ["line one", "line two"] }
    FunCi::Tui::LoopingAnimationPlayer.new({ name: "test", fps: 4, frames: frames })
  end
end

class TestLoopingAnimationPlayerRendering < Minitest::Test
  def test_should_return_centered_lines_for_current_frame
    # Given a player with distinct frames
    player = make_player_with_frames([["hello", "world"], ["foo", "bar"]])

    # When we get current lines for width 20
    lines = player.current_lines(20)

    # Then we should get 2 lines, each padded for centering
    assert_equal 2, lines.length
    lines.each do |line|
      stripped = FunCi::Tui::Ansi.strip(line)
      assert stripped.start_with?(" "), "Line should be padded: #{stripped.inspect}"
    end
  end

  def test_should_return_correct_frame_content_after_wrap
    # Given a player with 2 frames
    player = make_player_with_frames([["frame-zero"], ["frame-one"]])

    # When we advance past the total (wraps to frame 0)
    2.times { player.advance! }

    # Then current_lines should show frame 0 content
    lines = player.current_lines(40)
    plain = FunCi::Tui::Ansi.strip(lines[0])
    assert_match(/frame-zero/, plain, "Should show frame 0 after wrapping")
  end

  def test_should_append_erase_to_eol_on_each_line
    # Given a player with one frame
    player = make_player_with_frames([["abc"]])

    # When we get the lines
    lines = player.current_lines(40)

    # Then each line should end with erase-to-EOL
    lines.each do |line|
      assert line.end_with?("\e[K"), "Line should end with \\e[K: #{line.inspect}"
    end
  end

  private

  def make_player_with_frames(frames)
    FunCi::Tui::LoopingAnimationPlayer.new({ name: "test", fps: 4, frames: frames })
  end
end
