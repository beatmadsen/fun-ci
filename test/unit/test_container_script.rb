# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../script/record_evidence_fixture"

# What script/record_evidence_fixture.rb runs in a recipe's image. The image
# runs as root, and on Linux what root writes into the project and out
# directories is root's, which the host's user can't delete afterwards; so
# the script hands both back to the host's user when it is done.
class TestContainerScript < Minitest::Test
  RECIPE = { "setup" => "true", "command" => "cargo test", "version" => "cargo --version" }.freeze

  def test_should_hand_what_the_container_wrote_back_to_the_host_s_user
    assert_match(%r{; chown -R 501:20 /work /out\z}, container_script(RECIPE, "501:20"))
  end
end
