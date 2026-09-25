# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/fixture_replay"

# AT-2.2: given the renderer's lines of each contract fixture, ConsoleSession
# sends exactly the fixture's Ruby lines, in order and JSON-equal. The Rust
# suite reads the same files from the other side (AT-3.5).
class TestContractFixtures < Minitest::Test
  FIXTURES = Dir[File.expand_path("../../contract/fixtures/*.jsonl", __dir__)]

  def test_there_are_fixtures_to_replay
    refute_empty FIXTURES
  end

  FIXTURES.each do |path|
    name = File.basename(path, ".jsonl")
    define_method("test_console_session_holds_the_#{name.tr("-", "_")}_conversation") do
      replay = FixtureReplay.new(FixtureReplay.lines(path))

      assert_equal replay.expected, replay.conversation
    end
  end
end
