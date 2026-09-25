# frozen_string_literal: true

# One-off (AT-3.6): writes renderer/animations/<name>.json from each
# lib/fun_ci/animations/*.rb module. test/unit/contract/test_animation_json.rb
# fails if the JSON and the Ruby modules drift apart before §5 deletes them.
#
#   ruby renderer/tools/convert_animations.rb

require "fileutils"
require_relative "../../contract/capture/animation_json"

out = File.expand_path("../animations", __dir__)
FileUtils.mkdir_p(out)
FunCi::Contract::AnimationJson.all.each do |animation|
  File.write(File.join(out, "#{animation.name}.json"), animation.json)
end
