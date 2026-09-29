# frozen_string_literal: true

require_relative "../test_helper"
require_relative "agent_client"

# `fun-ci status` says how the commit stands against the trunk (acceptance-tests.md, AT-11.28).
class TestAgentTrunkStatus < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  MERGE = FunCi::Trunk::Merge
  PASSED = { "lint" => "completed", "build" => "completed", "fast" => "completed" }.freeze

  def setup
    @client = AgentClient.open
    @client.git.commit(SHA, "Add shipping to the cart total")
    @client.record_run(SHA, branch: "feat/cart", stages: PASSED)
  end

  def teardown = @client.close

  def test_should_print_the_trunk_its_age_and_the_counts_when_the_commit_conflicts
    @client.record_trunk_check(SHA, MERGE.conflicts(["lib/cart.rb", "lib/total.rb"], ahead: 3, behind: 4),
                               seen: @client.clock.now - 120)

    @client.status

    assert_includes @client.stdout,
                    "  trunk  conflicts    origin/main 9e1d004, fetched 2m ago, 3 ahead, 4 behind\n    " \
                    "lib/cart.rb\n    lib/total.rb\n"
  end

  def test_should_say_when_and_how_to_integrate_a_branch_that_conflicts
    @client.record_trunk_check(SHA, MERGE.conflicts(["lib/cart.rb", "lib/total.rb"], ahead: 3, behind: 4),
                               seen: @client.clock.now - 120)

    @client.status

    assert_includes @client.stdout,
                    "Conflicts with origin/main in 2 files. When the task is done, integrate: git pull origin main " \
                    "(or git pull --rebase origin main if the branch isn't shared)\n"
  end

  def test_should_print_no_trunk_line_while_the_check_is_going
    @client.start_trunk_check(SHA)

    @client.status

    refute_includes @client.stdout, "trunk"
  end

  def test_should_say_a_check_that_never_finished_is_unknown
    @client.start_trunk_check(SHA)
    @client.clock.pause(60)

    @client.status

    assert_includes @client.stdout, "  trunk  unknown      the check never finished\n"
  end

  def test_should_mark_a_trunk_fetched_over_an_hour_ago_stale
    @client.record_trunk_check(SHA, MERGE.clean(ahead: 1, behind: 1), seen: @client.clock.now - 7200)

    @client.status

    assert_includes @client.stdout, "fetched 2h ago, STALE, 1 ahead, 1 behind\n"
  end

  def test_should_say_why_the_last_fetch_failed
    @client.record_trunk_check(SHA, MERGE.clean(ahead: 1, behind: 1), seen: @client.clock.now - 120)
    @client.record_trunk_fetch(FunCi::Trunk::Fetched.new(error: "fatal: could not resolve host"))

    @client.status

    assert_includes @client.stdout, "fetched 2m ago, STALE (fetch failed: fatal: could not resolve host), 1 ahead"
  end
end
