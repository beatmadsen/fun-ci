# frozen_string_literal: true

require_relative "../test_helper"
require_relative "agent_client"

# `fun-ci status` says how the commit stands against the trunk (docs/trunk-conflicts.md, AT-11.28).
class TestAgentTrunkStatus < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  TRUNK_SHA = "9e1d004aaaabbbbccccddddeeeeffff000011112"
  PASSED = { "lint" => "completed", "build" => "completed", "fast" => "completed" }.freeze

  def setup
    @client = AgentClient.open
    @client.git.commit(SHA, "Add shipping to the cart total")
    @client.record_run(SHA, branch: "feat/cart", stages: PASSED)
  end

  def teardown = @client.close

  def test_should_print_the_trunk_its_age_and_the_counts_when_the_commit_conflicts
    @client.record_trunk_check(SHA, trunk_sha: TRUNK_SHA, seen: @client.clock.now - 120, outcome: "conflicts",
                                    ahead: 3, behind: 4, files: ["lib/cart.rb", "lib/total.rb"])

    @client.status

    assert_includes @client.stdout,
                    "  trunk  conflicts    origin/main 9e1d004, fetched 2m ago, 3 ahead, 4 behind\n" \
                    "    lib/cart.rb\n    lib/total.rb\n"
  end
end
