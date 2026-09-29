# frozen_string_literal: true

require_relative "../test_helper"
require_relative "agent_client"

# `fun-ci runs` marks a run whose commit conflicts with the trunk (acceptance-tests.md, AT-11.37).
class TestAgentTrunkRuns < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"

  def setup
    @client = AgentClient.open
    @client.git.commit(SHA, "Add shipping to the cart total")
    @client.record_run(SHA, branch: "feat/cart", stages: { "lint" => "completed" })
  end

  def teardown = @client.close

  def test_should_mark_a_run_that_conflicts_before_its_subject
    @client.record_trunk_check(SHA, FunCi::Trunk::Merge.conflicts(["a.rb"], ahead: 1, behind: 1),
                               seen: @client.clock.now)
    @client.runs

    assert_includes @client.stdout, "conflicts origin/main  Add shipping to the cart total"
  end
end
