# frozen_string_literal: true

require_relative "../../test/test_helper"
require_relative "binary_conversation"

# AT-3.8: Ruby drives the real renderer binary, on a pseudo-terminal, through
# the happy-7 contract fixture. `rake contract:binary` builds the binary and
# runs this; FUN_CI_RENDERER names the binary.
class TestRendererBinary < Minitest::Test
  FIXTURE = File.expand_path("../fixtures/happy-7.jsonl", __dir__)

  def setup
    lines = FixtureReplay.lines(FIXTURE)
    @expected = lines.reject { |line| line.key?("state") }
    @conversation, @status = BinaryConversation.new(ENV.fetch("FUN_CI_RENDERER"), lines).play
  end

  def test_should_hold_the_happy_7_conversation_with_the_real_binary
    assert_equal @expected, @conversation
  end

  def test_should_exit_cleanly_once_told_to_quit
    assert_predicate @status, :success?
  end
end
