# frozen_string_literal: true

require_relative "../test_helper"
require_relative "agent_client"

# A trunk that has moved since a run's check (docs/trunk-conflicts.md, AT-11.26).
class TestAgentTrunkMoved < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  MOVED_TO = "1a2b3c4dddddeeeeeffff000001111122222333"
  PASSED = { "lint" => "completed", "build" => "completed", "fast" => "completed" }.freeze
  MERGE = FunCi::Trunk::Merge

  def setup
    @client = AgentClient.open
    @client.git.commit(SHA, "Add shipping to the cart total")
    @client.record_run(SHA, stages: PASSED)
    @client.record_trunk_check(SHA, MERGE.conflicts(["lib/cart.rb"], ahead: 1, behind: 1), seen: @client.clock.now)
    @client.trunk.sha = MOVED_TO
    @client.trunk.merge = MERGE.clean(ahead: 1, behind: 2)
  end

  def teardown = @client.close

  def test_should_say_the_trunk_has_moved_since_the_check
    @client.status

    assert_includes @client.stdout, "    origin/main has moved to 1a2b3c4 since; fun-ci status --trunk checks again\n"
  end

  def test_should_check_again_when_asked_about_the_trunk
    assert_equal 0, @client.status("--trunk")
  end

  def test_should_keep_the_check_made_again
    @client.status("--trunk")
    @client.status

    assert_includes @client.stdout, "  trunk  clean        origin/main 1a2b3c4"
  end
end
