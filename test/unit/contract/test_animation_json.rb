# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../contract/capture/animation_json"

# AT-3.6: renderer/animations/*.json are the 1.x Ruby animations as data.
# Until §5 deletes the Ruby modules, the JSON must stay a faithful conversion.
class TestAnimationJson < Minitest::Test
  JSON_DIR = File.expand_path("../../../renderer/animations", __dir__)
  ANIMATIONS = FunCi::Contract::AnimationJson.all.to_h { |animation| [animation.name, animation] }
  DATA = { fps: 8, frames: [["\e[1;31m*\e[0m ", "  "]] }.freeze

  ANIMATIONS.each do |name, animation|
    define_method("test_the_checked_in_#{name}_json_is_the_conversion_of_the_ruby_module") do
      assert_equal animation.json, File.read(File.join(JSON_DIR, "#{name}.json"))
    end
  end

  def test_every_ruby_animation_has_a_json_file
    assert_equal ANIMATIONS.keys.sort, Dir[File.join(JSON_DIR, "*.json")].map { |p| File.basename(p, ".json") }.sort
  end

  def test_frame_duration_comes_from_fps
    assert_equal 125, convert(DATA)["frame_ms"]
  end

  def test_idle_and_running_loop
    assert_equal([true, true], %w[idle running].map { |name| ANIMATIONS[name].to_h["loop"] })
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
