# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../contract/capture/animation_json"

# AT-3.6: converting a 1.x Ruby animation module into the renderer's JSON.
# test/policy/test_animation_json_drift.rb holds the checked-in files to it.
class TestAnimationJson < Minitest::Test
  ANIMATIONS = FunCi::Contract::AnimationJson.all.to_h { |animation| [animation.name, animation] }
  DATA = { fps: 8, frames: [["\e[1;31m*\e[0m ", "  "]] }.freeze

  def test_frame_duration_comes_from_fps
    assert_equal 125, convert(DATA)["frame_ms"]
  end

  def test_the_idle_animation_loops
    assert ANIMATIONS["idle"].to_h["loop"]
  end

  def test_the_running_animation_loops
    assert ANIMATIONS["running"].to_h["loop"]
  end

  def test_event_animations_play_once
    refute ANIMATIONS["explosion"].to_h["loop"]
  end

  def test_a_frame_is_its_text_and_a_style_mask
    assert_equal({ "text" => ["* ", "  "], "style" => ["a ", "  "] }, convert(DATA)["frames"].first)
  end

  def test_styles_are_keyed_by_mask_character
    assert_equal({ "a" => { "fg" => 1, "bold" => true } }, convert(DATA)["styles"])
  end

  def test_a_line_that_leaves_a_style_in_force_is_refused
    assert_raises(ArgumentError) { convert(fps: 8, frames: [["\e[1;31m*"]]) }
  end

  private

  def convert(data) = FunCi::Contract::AnimationJson.new("test", data).to_h
end
