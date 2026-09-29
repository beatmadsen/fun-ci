# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require_relative "agent_client"

# `status --json` and `runs --json` carry how the commit stands against the trunk
# (acceptance-tests.md, AT-11.36).
class TestAgentTrunkJson < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  MERGE = FunCi::Trunk::Merge
  PASSED = { "lint" => "completed", "build" => "completed", "fast" => "completed" }.freeze

  def setup
    @client = AgentClient.open
    @client.git.commit(SHA, "Add shipping to the cart total")
    @client.record_run(SHA, branch: "feat/cart", stages: PASSED)
  end

  def teardown = @client.close

  def test_should_give_every_fact_of_the_check
    @client.record_trunk_check(SHA, MERGE.conflicts(["lib/cart.rb"], ahead: 3, behind: 4), seen: seen)
    @client.record_trunk_fetch(FunCi::Trunk::Fetched.new(error: nil))
    @client.status("--json")

    assert_equal({ "state" => "conflicts", "ref" => "origin/main", "sha" => TrunkKit::TRUNK_SHA,
                   "as_of" => seen.utc.iso8601, "stale" => false, "fetch" => "ok", "fetch_error" => nil,
                   "ahead" => 3, "behind" => 4, "files" => ["lib/cart.rb"], "reason" => nil, "moved_to" => nil },
                 document["trunk"])
  end

  def test_should_give_no_trunk_for_a_run_that_began_no_check
    @client.status("--json")

    assert_nil document.fetch("trunk")
  end

  def test_should_give_the_trunk_of_each_run_listed
    @client.record_trunk_check(SHA, MERGE.clean(ahead: 1, behind: 1), seen: seen)
    @client.runs("--json")

    assert_equal(["clean"], JSON.parse(@client.stdout).map { |run| run["trunk"]["state"] })
  end

  private

  def seen = Time.at(@client.clock.now.to_i - 120)
  def document = JSON.parse(@client.stdout)
end
