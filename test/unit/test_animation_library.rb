# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/animation_library"
require "fun_ci/tui/ansi"

class TestAnimationLibraryFailure < Minitest::Test
  def test_should_return_explosion_data_for_failure
    # When we request a failure animation
    data = FunCi::Tui::AnimationLibrary.random_failure

    # Then it should be the explosion animation with required keys
    assert_equal "Explosion", data[:name]
    assert_kind_of Array, data[:frames]
    assert data[:fps] > 0, "fps should be positive"
  end
end

class TestAnimationLibrarySuccess < Minitest::Test
  def test_should_have_multiple_success_animations
    # Then the library should contain more than one success option
    assert FunCi::Tui::AnimationLibrary::SUCCESS.length > 1,
      "Should have multiple success animations for variety"
  end

  def test_should_return_a_success_animation_with_required_keys
    # When we request any success animation
    data = FunCi::Tui::AnimationLibrary::SUCCESS.first

    # Then it should have name, fps, and non-empty frames
    assert data[:name], "Should have :name"
    assert data[:fps] > 0, "fps should be positive"
    assert data[:frames].length > 0, "Should have at least one frame"
  end

  def test_should_return_animation_data_from_random_success
    # When we request a random success animation
    data = FunCi::Tui::AnimationLibrary.random_success

    # Then it should have the required structure
    assert data[:name], "Should have :name"
    assert_kind_of Array, data[:frames]
    assert data[:fps] > 0, "fps should be positive"
    assert FunCi::Tui::AnimationLibrary::SUCCESS.include?(data),
      "Should return one of the registered success animations"
  end
end

class TestAnimationLibraryRunning < Minitest::Test
  def test_should_return_running_animation_with_required_keys
    # When we request the running animation
    data = FunCi::Tui::AnimationLibrary.running

    # Then it should have name, fps, and non-empty frames
    assert_equal "Running", data[:name]
    assert_kind_of Array, data[:frames]
    assert data[:fps] > 0, "fps should be positive"
    assert data[:frames].length > 1, "Should have multiple frames for looping"
  end
end

class TestAnimationLibraryDataIntegrity < Minitest::Test
  def test_should_have_multi_line_frames_as_string_arrays
    # Given a representative animation (explosion)
    data = FunCi::Animations::Explosion::DATA

    # Then each frame should be an array of strings
    first_frame = data[:frames].first
    assert_kind_of Array, first_frame, "Frame should be an Array"
    assert_kind_of String, first_frame.first, "Frame lines should be Strings"
  end

  def test_should_have_equal_visible_line_lengths_within_each_frame
    # Given a representative animation (explosion)
    data = FunCi::Animations::Explosion::DATA

    # Then lines within each frame should have equal visible width
    data[:frames].each_with_index do |frame, i|
      lengths = frame.map { |l| FunCi::Tui::Ansi.strip(l).length }
      assert_equal 1, lengths.uniq.length,
        "#{data[:name]} frame #{i} has unequal line lengths: #{lengths.uniq}"
    end
  end
end
