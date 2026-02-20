# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/spinner"

class TestSpinner < Minitest::Test
  def test_should_have_8_braille_frames
    spinner = FunCi::Spinner.new
    assert_equal 8, spinner.frames.length, "Braille spinner should have 8 frames"
  end

  def test_should_return_first_frame_initially
    spinner = FunCi::Spinner.new
    assert_equal "\u2800", spinner.current_frame, "Should start at first frame"
  end

  def test_should_cycle_to_next_frame
    spinner = FunCi::Spinner.new
    first = spinner.current_frame
    spinner.advance!
    second = spinner.current_frame
    refute_equal first, second, "Advancing should change the frame"
  end

  def test_should_wrap_around_after_last_frame
    spinner = FunCi::Spinner.new
    # Advance through all 8 frames
    8.times { spinner.advance! }
    # Should be back to first frame
    assert_equal spinner.frames[0], spinner.current_frame, "Should wrap around to first frame"
  end
end
