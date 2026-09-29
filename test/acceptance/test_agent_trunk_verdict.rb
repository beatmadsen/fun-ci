# frozen_string_literal: true

require_relative "../test_helper"
require_relative "agent_client"

# An agent that asks with --trunk branches on the trunk too (docs/trunk-conflicts.md, AT-11.32 to AT-11.35).
class TestAgentTrunkVerdict < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  PASSED = { "lint" => "completed", "build" => "completed", "fast" => "completed" }.freeze
  MERGE = FunCi::Trunk::Merge
  CONFLICTS = MERGE.conflicts(["lib/cart.rb"], ahead: 3, behind: 4)

  def setup
    @client = AgentClient.open
    @client.git.commit(SHA, "Add shipping to the cart total")
  end

  def teardown = @client.close

  def test_should_exit_conflicts_for_a_passed_run_that_conflicts
    @client.record_run(SHA, stages: PASSED)
    @client.record_trunk_check(SHA, CONFLICTS, seen: @client.clock.now)

    assert_equal 6, @client.status("--trunk")
  end

  def test_should_exit_failed_for_a_failed_run_that_conflicts
    @client.record_run(SHA, stages: PASSED.merge("fast" => "failed"))
    @client.record_trunk_check(SHA, CONFLICTS, seen: @client.clock.now)

    assert_equal 1, @client.status("--trunk")
  end

  def test_should_exit_with_the_verdict_alone_when_the_trunk_is_unknown
    @client.record_run(SHA, stages: PASSED)
    @client.record_trunk_check(SHA, MERGE.unknown("no trunk found"), seen: @client.clock.now)

    assert_equal 0, @client.status("--trunk")
  end

  def test_should_exit_undecided_while_the_check_is_going
    @client.record_run(SHA, stages: PASSED)
    @client.start_trunk_check(SHA)

    assert_equal 3, @client.status("--trunk")
  end

  def test_should_say_the_check_is_going_when_asked_with_trunk
    @client.record_run(SHA, stages: PASSED)
    @client.start_trunk_check(SHA)
    @client.status("--trunk")

    assert_includes @client.stdout, "  trunk  checking\n"
  end

  def test_should_wait_for_the_check_to_finish
    @client.record_run(SHA, stages: PASSED)
    @client.start_trunk_check(SHA)
    @client.clock.then_do { @client.record_trunk_check(SHA, CONFLICTS, seen: @client.clock.now) }

    assert_equal 6, @client.wait("--trunk")
  end
end
