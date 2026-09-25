# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/header_animation_player"
require "fun_ci/tui/ansi"

class TestHeaderAnimationPlayerLifecycle < Minitest::Test
  def test_should_start_at_frame_zero
    player = make_player(frame_count: 3)
    assert_equal 0, player.frame
  end

  def test_should_increment_frame_on_advance
    player = make_player(frame_count: 3)
    player.advance!
    assert_equal 1, player.frame
  end

  def test_should_be_finished_when_frame_reaches_total
    player = make_player(frame_count: 2)
    2.times { player.advance! }
    assert player.finished?, "Should be finished after all frames played"
  end

  def test_should_not_be_finished_before_reaching_total
    player = make_player(frame_count: 2)
    player.advance!
    refute player.finished?, "Should not be finished mid-animation"
  end

  def test_should_report_total_frames_from_data
    player = make_player(frame_count: 5)
    assert_equal 5, player.total_frames
  end

  private

  def make_player(frame_count:)
    frames = frame_count.times.map { ["line one", "line two"] }
    FunCi::Tui::HeaderAnimationPlayer.new({ name: "test", fps: 8, frames: frames })
  end
end

class TestHeaderAnimationPlayerRendering < Minitest::Test
  def test_should_return_centered_lines_for_current_frame
    player = make_player_with_frames([%w[hello world]])

    lines = player.current_lines(20)

    assert_equal 2, lines.length
    lines.each do |line|
      stripped = FunCi::Tui::Ansi.strip(line)
      assert stripped.start_with?(" "), "Line should be padded: #{stripped.inspect}"
    end
  end

  def test_should_return_empty_lines_when_finished
    player = make_player_with_frames([["hi"]])
    player.advance!

    assert_equal [], player.current_lines(80)
  end

  def test_should_append_erase_to_eol_on_each_line
    player = make_player_with_frames([["abc"]])

    lines = player.current_lines(40)

    lines.each do |line|
      assert line.end_with?("\e[K"), "Line should end with \\e[K: #{line.inspect}"
    end
  end

  def test_should_center_using_visible_width_ignoring_ansi
    # "HI" is 2 visible chars, so centring in width 10 pads (10 - 2) / 2 = 4 spaces
    colored = "\e[1;32mHI\e[0m"
    player = make_player_with_frames([[colored]])

    lines = player.current_lines(10)

    assert lines[0].start_with?("    \e[1;32mHI\e[0m"),
           "Should pad based on visible width, not byte length"
  end

  def test_should_return_lines_with_no_padding_when_width_is_zero
    player = make_player_with_frames([["hello"]])

    lines = player.current_lines(0)

    assert_equal 1, lines.length
    assert lines[0].start_with?("hello"), "Should not crash or pad negatively"
  end

  def test_should_return_empty_lines_when_advanced_past_last_frame
    player = make_player_with_frames([["a"], ["b"]])
    5.times { player.advance! }

    assert_equal [], player.current_lines(80)
    assert player.finished?, "Should remain finished after over-advancing"
  end

  private

  def make_player_with_frames(frames)
    FunCi::Tui::HeaderAnimationPlayer.new({ name: "test", fps: 8, frames: frames })
  end
end
