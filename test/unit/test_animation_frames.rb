# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/animation_frames"
require "fun_ci/ansi"

class TestAnimationFramesFailure < Minitest::Test
  def test_failure_particles_has_7_frames
    assert_equal 7, FunCi::AnimationFrames.failure_particles.length
  end

  def test_first_particle_frame_is_bold_red
    frame = FunCi::AnimationFrames.failure_particles[0]
    assert_equal "*", frame[:chars]
    assert_equal "\e[1;31m", frame[:color]
  end

  def test_last_particle_frame_is_empty
    frame = FunCi::AnimationFrames.failure_particles[6]
    assert_equal "", frame[:chars]
  end

  def test_mid_frames_are_orange
    frame = FunCi::AnimationFrames.failure_particles[2]
    assert_equal "\e[38;5;208m", frame[:color]
  end

  def test_failure_header_has_7_frames
    frames = FunCi::AnimationFrames.failure_header(80)
    assert_equal 7, frames.length
  end

  def test_failure_header_first_and_last_are_nil
    frames = FunCi::AnimationFrames.failure_header(80)
    assert_nil frames[0]
    assert_nil frames[6]
  end

  def test_failure_header_contains_boom
    frames = FunCi::AnimationFrames.failure_header(80)
    assert_match(/BOOM/, FunCi::Ansi.strip(frames[1]))
  end

  def test_failure_footer_has_5_frames
    frames = FunCi::AnimationFrames.failure_footer("fast", 80)
    assert_equal 5, frames.length
  end

  def test_failure_footer_contains_stage_name
    frames = FunCi::AnimationFrames.failure_footer("fast", 80)
    assert_match(/FAST FAILED/, FunCi::Ansi.strip(frames[1]))
  end

  def test_failure_footer_first_and_last_are_nil
    frames = FunCi::AnimationFrames.failure_footer("fast", 80)
    assert_nil frames[0]
    assert_nil frames[4]
  end
end

class TestAnimationFramesSuccess < Minitest::Test
  def test_success_header_has_8_frames
    frames = FunCi::AnimationFrames.success_header(80)
    assert_equal 8, frames.length
  end

  def test_success_header_contains_all_passed
    frames = FunCi::AnimationFrames.success_header(80)
    assert_match(/ALL PASSED/, FunCi::Ansi.strip(frames[1]))
  end

  def test_success_header_first_and_last_are_nil
    frames = FunCi::AnimationFrames.success_header(80)
    assert_nil frames[0]
    assert_nil frames[7]
  end

  def test_success_footer_has_5_frames
    frames = FunCi::AnimationFrames.success_footer(80)
    assert_equal 5, frames.length
  end

  def test_success_footer_contains_nice
    frames = FunCi::AnimationFrames.success_footer(80)
    assert_match(/NICE!/, FunCi::Ansi.strip(frames[1]))
  end
end

class TestAnimationFramesTimeout < Minitest::Test
  def test_timeout_header_has_4_frames
    frames = FunCi::AnimationFrames.timeout_header(80)
    assert_equal 4, frames.length
  end

  def test_timeout_header_contains_timed_out
    frames = FunCi::AnimationFrames.timeout_header(80)
    assert_match(/TIMED OUT/, FunCi::Ansi.strip(frames[1]))
  end
end

class TestAnimationFramesColors < Minitest::Test
  def test_stage_pass_colors_has_3_entries
    assert_equal 3, FunCi::AnimationFrames.stage_pass_colors.length
  end

  def test_stage_pass_first_is_bold_yellow
    assert_equal "\e[1;33m", FunCi::AnimationFrames.stage_pass_colors[0]
  end

  def test_timeout_colors_has_4_entries
    assert_equal 4, FunCi::AnimationFrames.timeout_colors.length
  end

  def test_failure_header_uses_dark_red_bg_on_frame_2
    frames = FunCi::AnimationFrames.failure_header(80)
    assert_match(/\e\[48;5;124m/, frames[1])
  end

  def test_success_header_uses_dark_green_bg
    frames = FunCi::AnimationFrames.success_header(80)
    assert_match(/\e\[48;5;22m/, frames[1])
  end
end
