# frozen_string_literal: true

require_relative "../test_helper"
require_relative "agent_client"

# `fun-ci status` says where a commit's run stands (acceptance-tests.md, AT-9.2).
class TestAgentStatus < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  PASSED_TO_FAST = { "lint" => "completed", "build" => "completed", "fast" => "completed" }.freeze

  def setup
    @client = AgentClient.open
    @client.git.commit(SHA, "Add retry to fetch")
  end

  def teardown = @client.close

  def test_should_name_the_commit_and_its_branch_when_asked_about_head
    @client.record_run(SHA, branch: "main", stages: { "lint" => "completed" })

    @client.status

    assert_includes @client.stdout, %(fun-ci: 3f9c2ab "Add retry to fetch" on main)
  end

  def test_should_exit_passed_when_the_stages_the_agent_needs_passed
    @client.record_run(SHA, stages: PASSED_TO_FAST.merge("slow" => "running"))

    assert_equal 0, @client.status
  end

  def test_should_exit_undecided_when_the_agent_needs_the_slow_suite_still_running
    @client.record_run(SHA, stages: PASSED_TO_FAST.merge("slow" => "running"))

    assert_equal 3, @client.status("--need", "all")
  end

  def test_should_say_there_is_no_run_when_the_commit_has_none
    assert_equal [5, "fun-ci: no run for 3f9c2ab in this project.\n"], [@client.status, @client.stdout]
  end

  def test_should_refuse_a_revision_git_cannot_find
    assert_equal [64, "fun-ci status: git can't find the commit 'nosuch'\n"],
                 [@client.status("nosuch"), @client.stdout]
  end

  def test_should_answer_for_the_revision_named
    @client.git.commit("bcd2345aaaa", "Later work")
    @client.record_run(SHA, stages: PASSED_TO_FAST)

    assert_equal 0, @client.status("3f9c2ab")
  end
end
