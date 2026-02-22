# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/animation_frames"
require "fun_ci/tui/ansi"

class TestAnimationFramesFailure < Minitest::Test
  def test_failure_particles_has_7_frames
    assert_equal 7, FunCi::Tui::AnimationFrames.failure_particles.length
  end

  def test_first_particle_frame_is_bold_red
    frame = FunCi::Tui::AnimationFrames.failure_particles[0]
    assert_equal "*", frame[:chars]
    assert_equal "\e[1;31m", frame[:color]
  end

  def test_last_particle_frame_is_empty
    frame = FunCi::Tui::AnimationFrames.failure_particles[6]
    assert_equal "", frame[:chars]
  end

  def test_mid_frames_are_orange
    frame = FunCi::Tui::AnimationFrames.failure_particles[2]
    assert_equal "\e[38;5;208m", frame[:color]
  end

  def test_failure_header_has_7_frames
    frames = FunCi::Tui::AnimationFrames.failure_header(80)
    assert_equal 7, frames.length
  end

  def test_failure_header_first_and_last_are_nil
    frames = FunCi::Tui::AnimationFrames.failure_header(80)
    assert_nil frames[0]
    assert_nil frames[6]
  end

  def test_failure_header_contains_boom
    frames = FunCi::Tui::AnimationFrames.failure_header(80)
    assert_match(/BOOM/, FunCi::Tui::Ansi.strip(frames[1]))
  end

  def test_failure_footer_has_40_frames
    # 5 visual frames * FOOTER_HOLD(8) = 40
    frames = FunCi::Tui::AnimationFrames.failure_footer("fast", 80)
    assert_equal 40, frames.length
  end

  def test_failure_footer_contains_stage_name
    # First visual content frame starts at index 8 (after 8 nils)
    frames = FunCi::Tui::AnimationFrames.failure_footer("fast", 80)
    assert_match(/FAST FAILED/, FunCi::Tui::Ansi.strip(frames[8]))
  end

  def test_failure_footer_first_and_last_are_nil
    frames = FunCi::Tui::AnimationFrames.failure_footer("fast", 80)
    assert_nil frames[0]
    assert_nil frames[39]
  end

  def test_failure_footer_holds_each_visual_frame_8_times
    frames = FunCi::Tui::AnimationFrames.failure_footer("fast", 80)
    # Frames 0-7 should all be nil (first visual frame held 8 times)
    8.times { |i| assert_nil frames[i], "Frame #{i} should be nil (held)" }
    # Frames 8-15 should all be the same content (second visual frame held 8 times)
    content = frames[8]
    refute_nil content, "Frame 8 should have content"
    (8..15).each { |i| assert_equal content, frames[i], "Frame #{i} should match frame 8" }
  end
end

class TestAnimationFramesSuccess < Minitest::Test
  def test_success_header_has_8_frames
    frames = FunCi::Tui::AnimationFrames.success_header(80)
    assert_equal 8, frames.length
  end

  def test_success_header_contains_all_passed
    frames = FunCi::Tui::AnimationFrames.success_header(80)
    assert_match(/ALL PASSED/, FunCi::Tui::Ansi.strip(frames[1]))
  end

  def test_success_header_first_and_last_are_nil
    frames = FunCi::Tui::AnimationFrames.success_header(80)
    assert_nil frames[0]
    assert_nil frames[7]
  end

  def test_success_footer_has_40_frames
    # 5 visual frames * FOOTER_HOLD(8) = 40
    frames = FunCi::Tui::AnimationFrames.success_footer(80)
    assert_equal 40, frames.length
  end

  def test_success_footer_contains_nice
    # First visual content frame starts at index 8 (after 8 nils)
    frames = FunCi::Tui::AnimationFrames.success_footer(80)
    assert_match(/NICE!/, FunCi::Tui::Ansi.strip(frames[8]))
  end

  def test_success_footer_holds_each_visual_frame_8_times
    frames = FunCi::Tui::AnimationFrames.success_footer(80)
    # Frames 8-15 should all be the same content
    content = frames[8]
    refute_nil content, "Frame 8 should have content"
    (8..15).each { |i| assert_equal content, frames[i], "Frame #{i} should match frame 8" }
  end
end

class TestAnimationFramesTimeout < Minitest::Test
  def test_timeout_header_has_4_frames
    frames = FunCi::Tui::AnimationFrames.timeout_header(80)
    assert_equal 4, frames.length
  end

  def test_timeout_header_contains_timed_out
    frames = FunCi::Tui::AnimationFrames.timeout_header(80)
    assert_match(/TIMED OUT/, FunCi::Tui::Ansi.strip(frames[1]))
  end
end

class TestAnimationFramesColors < Minitest::Test
  def test_stage_pass_colors_has_3_entries
    assert_equal 3, FunCi::Tui::AnimationFrames.stage_pass_colors.length
  end

  def test_stage_pass_first_is_bold_yellow
    assert_equal "\e[1;33m", FunCi::Tui::AnimationFrames.stage_pass_colors[0]
  end

  def test_timeout_colors_has_4_entries
    assert_equal 4, FunCi::Tui::AnimationFrames.timeout_colors.length
  end

  def test_failure_header_uses_dark_red_bg_on_frame_2
    frames = FunCi::Tui::AnimationFrames.failure_header(80)
    assert_match(/\e\[48;5;124m/, frames[1])
  end

  def test_success_header_uses_dark_green_bg
    frames = FunCi::Tui::AnimationFrames.success_header(80)
    assert_match(/\e\[48;5;22m/, frames[1])
  end
end
