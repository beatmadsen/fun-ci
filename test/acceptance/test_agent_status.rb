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

  def test_should_list_each_stage_with_its_state
    @client.record_run(SHA, stages: { "lint" => "completed", "build" => "running" })

    @client.status

    assert_match(/^  lint   passed .*\n  build  running\n  fast   waiting\n  slow   waiting +\(not needed\)$/,
                 @client.stdout)
  end

  def test_should_exit_undecided_while_a_needed_stage_runs
    @client.record_run(SHA, stages: { "lint" => "completed", "build" => "running" })

    assert_equal 3, @client.status
  end

  def test_should_exit_passed_when_the_stages_the_agent_needs_passed
    @client.record_run(SHA, stages: PASSED_TO_FAST.merge("slow" => "running"))

    assert_equal 0, @client.status
  end

  def test_should_exit_undecided_when_the_agent_needs_the_slow_suite_still_running
    @client.record_run(SHA, stages: PASSED_TO_FAST.merge("slow" => "running"))

    assert_equal 3, @client.status("--need", "all")
  end

  def test_should_exit_failed_when_a_needed_stage_failed
    @client.record_run(SHA, stages: { "lint" => "failed", "build" => "completed" })

    assert_equal 1, @client.status
  end

  def test_should_exit_over_budget_when_a_needed_stage_ran_out_of_time
    @client.record_run(SHA, stages: { "lint" => "completed", "build" => "timed_out" })

    assert_equal 2, @client.status
  end

  def test_should_name_the_newer_commit_when_the_run_was_superseded
    cancelled_run(SHA)
    @client.record_run("bcd2345aaaa")

    assert_equal [4, "Superseded by bcd2345."], [@client.status, @client.stdout.lines.last.chomp]
  end

  def test_should_say_there_is_no_run_when_the_commit_has_none
    assert_equal [5, "fun-ci: no run for 3f9c2ab in this project.\n"], [@client.status, @client.stdout]
  end

  def test_should_not_answer_with_another_project_s_run_of_the_commit
    @client.record_run(SHA, project: "/another/project", stages: PASSED_TO_FAST)

    assert_equal 5, @client.status
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

  private

  def cancelled_run(sha)
    FunCi::Persistence::PipelineRun.update_status(@client.db, @client.record_run(sha), "cancelled")
  end
end
