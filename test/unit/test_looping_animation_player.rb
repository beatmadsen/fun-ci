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
    player.advance!
    assert_equal 1, player.frame
  end

  def test_should_wrap_frame_after_reaching_total
    player = make_player(frame_count: 3)
    3.times { player.advance! }
    assert_equal 0, player.frame
  end

  def test_should_never_report_finished
    player = make_player(frame_count: 2)
    10.times { player.advance! }
    refute player.finished?, "Looping player should never be finished"
  end

  def test_should_return_correct_frame_after_multiple_loops
    player = make_player(frame_count: 3)
    ((3 * 3) + 1).times { player.advance! }
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
    player = make_player_with_frames([%w[hello world], %w[foo bar]])

    lines = player.current_lines(20)

    assert_equal 2, lines.length
    lines.each do |line|
      stripped = FunCi::Tui::Ansi.strip(line)
      assert stripped.start_with?(" "), "Line should be padded: #{stripped.inspect}"
    end
  end

  def test_should_return_correct_frame_content_after_wrap
    player = make_player_with_frames([["frame-zero"], ["frame-one"]])

    2.times { player.advance! }

    lines = player.current_lines(40)
    plain = FunCi::Tui::Ansi.strip(lines[0])
    assert_match(/frame-zero/, plain, "Should show frame 0 after wrapping")
  end

  def test_should_append_erase_to_eol_on_each_line
    player = make_player_with_frames([["abc"]])

    lines = player.current_lines(40)

    lines.each do |line|
      assert line.end_with?("\e[K"), "Line should end with \\e[K: #{line.inspect}"
    end
  end

  private

  def make_player_with_frames(frames)
    FunCi::Tui::LoopingAnimationPlayer.new({ name: "test", fps: 4, frames: frames })
  end
end
