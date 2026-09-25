# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../contract/capture/pinned_animations"

class TestPinnedAnimations < Minitest::Test
  def setup
    @library = FunCi::Contract::PinnedAnimations.new
  end

  def test_a_pinned_success_animation_replaces_the_random_choice
    @library.pin("celebrate")

    assert_same FunCi::Animations::Celebrate::DATA, @library.random_success
  end

  def test_pinning_a_failure_animation_leaves_the_success_choice_alone
    @library.pin("celebrate")
    @library.pin("explosion")

    assert_same FunCi::Animations::Celebrate::DATA, @library.random_success
  end

  def test_unpinned_choices_default_to_the_first_of_each_list
    assert_equal [FunCi::Animations::Success::DATA, FunCi::Animations::Explosion::DATA],
                 [@library.random_success, @library.random_failure]
  end

  def test_pinning_an_unknown_animation_names_it
    error = assert_raises(ArgumentError) { @library.pin("confetti") }

    assert_match(/confetti/, error.message)
  end

  def test_idle_and_running_are_the_1x_ones
    assert_equal [FunCi::Tui::AnimationLibrary.idle, FunCi::Tui::AnimationLibrary.running],
                 [@library.idle, @library.running]
  end
end
