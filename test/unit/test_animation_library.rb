# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/animation_library"
require "fun_ci/tui/ansi"

class TestAnimationLibraryFailure < Minitest::Test
  def test_should_return_explosion_data_for_failure
    data = FunCi::Tui::AnimationLibrary.random_failure
    assert_equal "Explosion", data[:name]
    assert_kind_of Array, data[:frames]
    assert data[:fps].positive?, "fps should be positive"
  end
end

class TestAnimationLibrarySuccess < Minitest::Test
  def test_should_have_multiple_success_animations
    assert FunCi::Tui::AnimationLibrary::SUCCESS.length > 1,
           "Should have multiple success animations for variety"
  end

  def test_should_return_a_success_animation_with_required_keys
    data = FunCi::Tui::AnimationLibrary::SUCCESS.first
    assert data[:name], "Should have :name"
    assert data[:fps].positive?, "fps should be positive"
    refute_empty data[:frames], "Should have at least one frame"
  end

  def test_should_return_animation_data_from_random_success
    data = FunCi::Tui::AnimationLibrary.random_success
    assert data[:name], "Should have :name"
    assert_kind_of Array, data[:frames]
    assert data[:fps].positive?, "fps should be positive"
    assert FunCi::Tui::AnimationLibrary::SUCCESS.include?(data),
           "Should return one of the registered success animations"
  end
end

class TestAnimationLibraryRunning < Minitest::Test
  def test_should_return_running_animation_with_required_keys
    data = FunCi::Tui::AnimationLibrary.running
    assert_equal "Running", data[:name]
    assert_kind_of Array, data[:frames]
    assert data[:fps].positive?, "fps should be positive"
    assert data[:frames].length > 1, "Should have multiple frames for looping"
  end
end

class TestAnimationLibraryDataIntegrity < Minitest::Test
  def test_should_have_multi_line_frames_as_string_arrays
    data = FunCi::Animations::Explosion::DATA
    first_frame = data[:frames].first
    assert_kind_of Array, first_frame, "Frame should be an Array"
    assert_kind_of String, first_frame.first, "Frame lines should be Strings"
  end

  def test_should_have_equal_visible_line_lengths_within_each_frame
    data = FunCi::Animations::Explosion::DATA
    data[:frames].each_with_index do |frame, i|
      lengths = frame.map { |l| FunCi::Tui::Ansi.strip(l).length }
      assert_equal 1, lengths.uniq.length,
                   "#{data[:name]} frame #{i} has unequal line lengths: #{lengths.uniq}"
    end
  end
end
