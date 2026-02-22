# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/animation"
require "fun_ci/animation_compositor"
require "fun_ci/ansi"

class TestAnimationCompositorHeaderOverlay < Minitest::Test
  def test_failure_header_at_frame_0_returns_nil
    anim = make_animation(:failure)
    assert_nil FunCi::AnimationCompositor.header_overlay(anim, 80)
  end

  def test_failure_header_at_frame_1_contains_boom
    anim = make_animation(:failure, advance: 1)
    overlay = FunCi::AnimationCompositor.header_overlay(anim, 80)
    assert_match(/BOOM/, FunCi::Ansi.strip(overlay))
  end

  def test_success_header_at_frame_1_contains_all_passed
    anim = make_animation(:success, advance: 1)
    overlay = FunCi::AnimationCompositor.header_overlay(anim, 80)
    assert_match(/ALL PASSED/, FunCi::Ansi.strip(overlay))
  end

  def test_timeout_header_at_frame_1_contains_timed_out
    anim = make_animation(:timeout, advance: 1)
    overlay = FunCi::AnimationCompositor.header_overlay(anim, 80)
    assert_match(/TIMED OUT/, FunCi::Ansi.strip(overlay))
  end

  def test_stage_pass_has_no_header
    anim = make_animation(:stage_pass)
    assert_nil FunCi::AnimationCompositor.header_overlay(anim, 80)
  end

  private

  def make_animation(type, advance: 0)
    anim = FunCi::Animation.new(type: type, run_id: 1, stage: "fast")
    advance.times { anim.advance! }
    anim
  end
end

class TestAnimationCompositorFooterOverlay < Minitest::Test
  def test_failure_footer_at_frame_8_contains_stage_name
    # Footer content starts at frame 8 due to FOOTER_HOLD(8) repeating nil 8 times
    anim = make_animation(:failure, stage: "fast", advance: 8)
    overlay = FunCi::AnimationCompositor.footer_overlay(anim, 80)
    assert_match(/FAST FAILED/, FunCi::Ansi.strip(overlay))
  end

  def test_success_footer_at_frame_8_contains_nice
    # Footer content starts at frame 8 due to FOOTER_HOLD(8) repeating nil 8 times
    anim = make_animation(:success, advance: 8)
    overlay = FunCi::AnimationCompositor.footer_overlay(anim, 80)
    assert_match(/NICE!/, FunCi::Ansi.strip(overlay))
  end

  def test_timeout_has_no_footer
    anim = make_animation(:timeout, advance: 1)
    assert_nil FunCi::AnimationCompositor.footer_overlay(anim, 80)
  end

  private

  def make_animation(type, stage: "fast", advance: 0)
    anim = FunCi::Animation.new(type: type, run_id: 1, stage: stage)
    advance.times { anim.advance! }
    anim
  end
end

class TestAnimationCompositorStageOverlay < Minitest::Test
  def test_stage_pass_flash_uses_bold_yellow_on_frame_0
    anim = FunCi::Animation.new(type: :stage_pass, run_id: 1, stage: "lint")
    overlay = FunCi::AnimationCompositor.stage_column_overlay(anim, "\e[32mLint 0.1s\e[0m", 0)
    assert_match(/\e\[1;33m/, overlay, "Frame 0 should use bold yellow")
    assert_match(/Lint 0\.1s/, overlay)
  end

  def test_stage_pass_flash_uses_bold_green_on_frame_1
    anim = FunCi::Animation.new(type: :stage_pass, run_id: 1, stage: "lint")
    anim.advance!
    overlay = FunCi::AnimationCompositor.stage_column_overlay(anim, "\e[32mLint 0.1s\e[0m", 0)
    assert_match(/\e\[1;32m/, overlay, "Frame 1 should use bold green")
  end

  def test_stage_pass_flash_uses_green_on_frame_2
    anim = FunCi::Animation.new(type: :stage_pass, run_id: 1, stage: "lint")
    2.times { anim.advance! }
    overlay = FunCi::AnimationCompositor.stage_column_overlay(anim, "\e[32mLint 0.1s\e[0m", 0)
    assert_match(/\e\[32m/, overlay, "Frame 2 should use normal green")
  end

  def test_failure_flanks_contain_particles_on_frame_0
    anim = FunCi::Animation.new(type: :failure, run_id: 1, stage: "fast")
    overlay = FunCi::AnimationCompositor.stage_column_overlay(anim, "\e[1;31mFast FAIL 6.2s\e[0m", 0)
    assert_match(/\*.*Fast FAIL 6\.2s.*\*/, FunCi::Ansi.strip(overlay))
  end

  def test_timeout_uses_bold_yellow_on_frame_0
    anim = FunCi::Animation.new(type: :timeout, run_id: 1, stage: "fast")
    overlay = FunCi::AnimationCompositor.stage_column_overlay(anim, "Fast TIMEOUT 10s", 0)
    assert_match(/\e\[1;33m/, overlay)
  end

  def test_success_sparkle_sweep_on_lint_at_frame_0
    anim = FunCi::Animation.new(type: :success, run_id: 1, stage: "lint")
    overlay = FunCi::AnimationCompositor.stage_column_overlay(anim, "\e[32mLint 0.1s\e[0m", 0)
    assert_match(/\e\[1;33m/, overlay, "Should have gold sparkle")
  end

  def test_success_sparkle_sweep_on_build_returns_nil_at_frame_0
    anim = FunCi::Animation.new(type: :success, run_id: 1, stage: "build")
    overlay = FunCi::AnimationCompositor.stage_column_overlay(anim, "\e[32mBuild 0.3s\e[0m", 0)
    assert_nil overlay
  end
end
