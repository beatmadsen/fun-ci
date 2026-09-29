# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require_relative "agent_client"

# `fun-ci why REV trunk` shows the conflict, merged again on demand
# (acceptance-tests.md, AT-11.38).
class TestAgentWhyTrunk < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  CART = "class Cart\n  def total\n    subtotal +\n<<<<<<< 3f9c2ab\n    shipping\n=======\n    tax\n" \
         ">>>>>>> origin/main\n  end\nend\n"
  EXPLAINED = FunCi::Trunk::Explained.new(
    messages: ["Auto-merging lib/cart.rb", "CONFLICT (content): Merge conflict in lib/cart.rb"],
    files: { "lib/cart.rb" => CART }
  )

  def setup
    @client = AgentClient.open
    @client.git.commit(SHA, "Add shipping to the cart total")
    @client.record_run(SHA, branch: "feat/cart", stages: { "lint" => "completed" })
    @client.record_trunk_check(SHA, FunCi::Trunk::Merge.conflicts(["lib/cart.rb"], ahead: 3, behind: 4),
                               seen: @client.clock.now)
    @client.trunk.explained = EXPLAINED
  end

  def teardown = @client.close

  def test_should_print_git_s_merge_messages
    @client.why("trunk")

    assert_includes @client.stdout, "  CONFLICT (content): Merge conflict in lib/cart.rb\n"
  end

  def test_should_print_each_conflicted_region_with_the_lines_around_it
    @client.why("trunk")

    assert_includes @client.stdout, "lib/cart.rb (lines 1-10), from merge-tree:\n     " \
                                    "1  class Cart\n     2    def total\n     3      subtotal +\n     " \
                                    "4  <<<<<<< 3f9c2ab\n"
  end

  def test_should_give_the_same_as_one_document
    @client.why("trunk", "--json")

    assert_equal "lib/cart.rb", JSON.parse(@client.stdout)["evidence"]["excerpts"].last["title"]
  end
end
