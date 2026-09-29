# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require_relative "agent_client"

# `fun-ci events` reports each check against the trunk (acceptance-tests.md, AT-11.39).
class TestAgentTrunkEvents < Minitest::Test
  SHA = "aaa1111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  MERGE = FunCi::Trunk::Merge
  CONFLICTS = MERGE.conflicts(["a.rb"], ahead: 1, behind: 1)

  def setup
    @client = AgentClient.open
    @client.git.commit(SHA, "Work")
    @client.record_run(SHA, branch: "feat/x", stages: { "lint" => "completed" })
  end

  def teardown = @client.close

  def test_should_print_a_check_recorded_as_it_happens
    @client.clock.then_do { @client.record_trunk_check(SHA, CONFLICTS, seen: @client.clock.now) }
    @client.clock.then_do { raise Interrupt }
    @client.events("--follow")

    assert_equal({ "event" => "trunk_checked", "commit" => SHA, "branch" => "feat/x", "state" => "conflicts" },
                 events.last.slice("event", "commit", "branch").merge("state" => events.last["trunk"]["state"]))
  end

  def test_should_print_a_check_made_again_against_a_moved_trunk
    @client.record_trunk_check(SHA, CONFLICTS, seen: @client.clock.now - 60)
    @client.clock.then_do do
      @client.record_trunk_check(SHA, MERGE.clean(ahead: 1, behind: 2), seen: @client.clock.now, trunk_sha: "fff9999")
    end
    @client.clock.then_do { raise Interrupt }
    @client.events("--follow")

    assert_equal %w[conflicts clean], trunk_states
  end

  def test_should_leave_checks_out_of_the_failures
    @client.record_trunk_check(SHA, CONFLICTS, seen: @client.clock.now)
    @client.events("--only", "failures")

    assert_empty trunk_states
  end

  private

  def events = @client.stdout.lines.map { |line| JSON.parse(line) }
  def trunk_states = events.select { |event| event["event"] == "trunk_checked" }.map { |event| event["trunk"]["state"] }
end
