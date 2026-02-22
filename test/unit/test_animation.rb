# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/animation"

class TestAnimationLifecycle < Minitest::Test
  def test_starts_at_frame_zero
    anim = FunCi::Animation.new(type: :failure, run_id: 1, stage: "fast")
    assert_equal 0, anim.frame
  end

  def test_advance_increments_frame
    anim = FunCi::Animation.new(type: :failure, run_id: 1, stage: "fast")
    anim.advance!
    assert_equal 1, anim.frame
  end

  def test_finished_when_frame_reaches_total
    anim = FunCi::Animation.new(type: :stage_pass, run_id: 1, stage: "lint")
    3.times { anim.advance! }
    assert anim.finished?, "Should be finished after 3 frames"
  end

  def test_not_finished_before_total_frames
    anim = FunCi::Animation.new(type: :stage_pass, run_id: 1, stage: "lint")
    2.times { anim.advance! }
    refute anim.finished?, "Should not be finished after 2 of 3 frames"
  end

  def test_exposes_type_run_id_and_stage
    anim = FunCi::Animation.new(type: :success, run_id: 42, stage: "slow")
    assert_equal :success, anim.type
    assert_equal 42, anim.run_id
    assert_equal "slow", anim.stage
  end

  def test_rejects_unknown_type
    assert_raises(ArgumentError) do
      FunCi::Animation.new(type: :unknown, run_id: 1)
    end
  end
end

class TestAnimationFrameCounts < Minitest::Test
  def test_failure_has_7_frames
    anim = FunCi::Animation.new(type: :failure, run_id: 1)
    assert_equal 7, anim.total_frames
  end

  def test_success_has_16_frames
    anim = FunCi::Animation.new(type: :success, run_id: 1)
    assert_equal 16, anim.total_frames
  end

  def test_stage_pass_has_3_frames
    anim = FunCi::Animation.new(type: :stage_pass, run_id: 1)
    assert_equal 3, anim.total_frames
  end

  def test_timeout_has_4_frames
    anim = FunCi::Animation.new(type: :timeout, run_id: 1)
    assert_equal 4, anim.total_frames
  end
end

class TestAnimationPriority < Minitest::Test
  def test_failure_has_highest_priority
    anim = FunCi::Animation.new(type: :failure, run_id: 1)
    assert_equal 3, anim.priority
  end

  def test_failure_outranks_success
    fail_anim = FunCi::Animation.new(type: :failure, run_id: 1)
    success_anim = FunCi::Animation.new(type: :success, run_id: 1)
    assert fail_anim.priority > success_anim.priority
  end

  def test_timeout_outranks_success
    timeout_anim = FunCi::Animation.new(type: :timeout, run_id: 1)
    success_anim = FunCi::Animation.new(type: :success, run_id: 1)
    assert timeout_anim.priority > success_anim.priority
  end
end

class TestAnimationHeaderFooter < Minitest::Test
  def test_failure_has_header_and_footer
    anim = FunCi::Animation.new(type: :failure, run_id: 1)
    assert anim.has_header?
    assert anim.has_footer?
  end

  def test_success_has_header_and_footer
    anim = FunCi::Animation.new(type: :success, run_id: 1)
    assert anim.has_header?
    assert anim.has_footer?
  end

  def test_timeout_has_header_but_no_footer
    anim = FunCi::Animation.new(type: :timeout, run_id: 1)
    assert anim.has_header?
    refute anim.has_footer?
  end

  def test_stage_pass_has_no_header_or_footer
    anim = FunCi::Animation.new(type: :stage_pass, run_id: 1)
    refute anim.has_header?
    refute anim.has_footer?
  end
end
