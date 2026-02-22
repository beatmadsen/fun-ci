# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/header_animation_player"
require "fun_ci/ansi"

class TestHeaderAnimationPlayerLifecycle < Minitest::Test
  def test_should_start_at_frame_zero
    player = make_player(frame_count: 3)
    assert_equal 0, player.frame
  end

  def test_should_increment_frame_on_advance
    player = make_player(frame_count: 3)
    # When we advance once
    player.advance!
    # Then frame should be 1
    assert_equal 1, player.frame
  end

  def test_should_be_finished_when_frame_reaches_total
    player = make_player(frame_count: 2)
    # When we advance past all frames
    2.times { player.advance! }
    # Then it should report finished
    assert player.finished?, "Should be finished after all frames played"
  end

  def test_should_not_be_finished_before_reaching_total
    player = make_player(frame_count: 2)
    # When we advance only partially
    player.advance!
    # Then it should not report finished
    refute player.finished?, "Should not be finished mid-animation"
  end

  def test_should_report_total_frames_from_data
    player = make_player(frame_count: 5)
    assert_equal 5, player.total_frames
  end

  private

  def make_player(frame_count:)
    frames = frame_count.times.map { ["line one", "line two"] }
    FunCi::HeaderAnimationPlayer.new({ name: "test", fps: 8, frames: frames })
  end
end

class TestHeaderAnimationPlayerRendering < Minitest::Test
  def test_should_return_centered_lines_for_current_frame
    # Given a player with a 2-line frame
    player = make_player_with_frames([["hello", "world"]])

    # When we get current lines for width 20
    lines = player.current_lines(20)

    # Then we should get 2 lines, each padded for centering
    assert_equal 2, lines.length
    lines.each do |line|
      stripped = FunCi::Ansi.strip(line)
      assert stripped.start_with?(" "), "Line should be padded: #{stripped.inspect}"
    end
  end

  def test_should_return_empty_lines_when_finished
    # Given a player with one frame, advanced past it
    player = make_player_with_frames([["hi"]])
    player.advance!

    # Then current_lines should be empty
    assert_equal [], player.current_lines(80)
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

  def test_should_center_using_visible_width_ignoring_ansi
    # Given a line with ANSI color codes ("HI" is 2 visible chars)
    colored = "\e[1;32mHI\e[0m"
    player = make_player_with_frames([[colored]])

    # When centered in width 10: (10-2)/2 = 4 spaces
    lines = player.current_lines(10)

    # Then it should have 4 spaces of left padding
    assert lines[0].start_with?("    \e[1;32mHI\e[0m"),
      "Should pad based on visible width, not byte length"
  end

  def test_should_return_lines_with_no_padding_when_width_is_zero
    # Given a player with content wider than width=0
    player = make_player_with_frames([["hello"]])

    # When we get lines with zero width
    lines = player.current_lines(0)

    # Then it should produce output without crashing (pad clamped to 0)
    assert_equal 1, lines.length
    assert lines[0].start_with?("hello"), "Should not crash or pad negatively"
  end

  def test_should_return_empty_lines_when_advanced_past_last_frame
    # Given a player that has been advanced well past its frame count
    player = make_player_with_frames([["a"], ["b"]])
    5.times { player.advance! }

    # Then current_lines should be empty and player should be finished
    assert_equal [], player.current_lines(80)
    assert player.finished?, "Should remain finished after over-advancing"
  end

  private

  def make_player_with_frames(frames)
    FunCi::HeaderAnimationPlayer.new({ name: "test", fps: 8, frames: frames })
  end
end
