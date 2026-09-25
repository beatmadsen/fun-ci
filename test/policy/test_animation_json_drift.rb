# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../contract/capture/animation_json"

# AT-3.6: renderer/animations/*.json are the 1.x Ruby animations as data.
# Until §5 deletes the Ruby modules, the checked-in JSON must stay their
# conversion; `ruby renderer/tools/convert_animations.rb` rewrites it.
class TestAnimationJsonDrift < Minitest::Test
  JSON_DIR = File.expand_path("../../renderer/animations", __dir__)
  ANIMATIONS = FunCi::Contract::AnimationJson.all.to_h { |animation| [animation.name, animation] }

  ANIMATIONS.each do |name, animation|
    define_method("test_the_checked_in_#{name}_json_is_the_conversion_of_the_ruby_module") do
      assert_equal animation.json, File.read(File.join(JSON_DIR, "#{name}.json"))
    end
  end

  def test_every_ruby_animation_has_a_json_file
    assert_equal ANIMATIONS.keys.sort, Dir[File.join(JSON_DIR, "*.json")].map { |p| File.basename(p, ".json") }.sort
  end
end
