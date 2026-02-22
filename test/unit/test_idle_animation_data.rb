# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/animations/idle"

class TestIdleAnimationData < Minitest::Test
  def test_should_have_at_least_two_frames
    frames = FunCi::Animations::Idle::DATA[:frames]
    assert frames.length >= 2, "Looping animation needs at least 2 frames"
  end

  def test_should_have_consistent_frame_heights
    frames = FunCi::Animations::Idle::DATA[:frames]
    heights = frames.map(&:length)
    # All frames should have the same number of lines
    assert_equal 1, heights.uniq.length,
      "All frames should have same height, got: #{heights.uniq.inspect}"
  end

  def test_should_have_14_lines_per_frame
    frames = FunCi::Animations::Idle::DATA[:frames]
    # The header height is 14 -- idle frames must fill the full space
    assert_equal 14, frames[0].length,
      "Idle frames should be 14 lines tall (HEADER_HEIGHT)"
  end

  def test_should_have_padded_lines_to_equal_width
    frames = FunCi::Animations::Idle::DATA[:frames]
    frames.each_with_index do |frame, fi|
      widths = frame.map { |l| l.gsub(/\e\[[0-9;]*m/, "").length }
      assert_equal 1, widths.uniq.length,
        "Frame #{fi}: all lines should have equal stripped width, got: #{widths.inspect}"
    end
  end

  def test_should_have_required_data_keys
    data = FunCi::Animations::Idle::DATA
    assert data[:name], "Should have a name"
    assert data[:fps], "Should have an fps"
    assert data[:frames], "Should have frames"
  end
end
