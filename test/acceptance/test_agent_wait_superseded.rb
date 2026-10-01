# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require "json"

# A run is only superseded by a newer commit nobody is waiting past, unless
# they follow the branch to it (acceptance-tests.md, AT-9.12).
class TestAgentWaitSuperseded < Minitest::Test
  OLD = "aaa1111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  NEW = "bbb2222bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  PASSED_TO_FAST = { "lint" => "completed", "build" => "completed", "fast" => "completed" }.freeze

  def setup
    @pipeline = TriggerCliClient.open(command_runner: INSTANT_SUCCESS_RUNNER)
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(OLD, "Old work")
    @agent.git.commit(NEW, "New work")
    @old_run = @agent.record_run(OLD, project: @pipeline.project_dir)
  end

  def teardown = @pipeline.close

  def test_should_not_cancel_a_run_an_agent_is_waiting_on_when_a_newer_commit_starts
    @agent.clock.then_do { @pipeline.trigger(commit_hash: NEW, branch: "main") }
    @agent.wait(OLD, "--within", "2")

    assert_equal "running", FunCi::Persistence::PipelineRun.find(@agent.db, @old_run)[:status]
  end

  # It asked to move on to a newer commit, so it keeps no run from being
  # superseded: each would run its slow suite beside the newest's.
  def test_should_cancel_a_run_an_agent_follows_the_branch_from_when_a_newer_commit_starts
    @agent.clock.then_do { @pipeline.trigger(commit_hash: NEW, branch: "main") }
    @agent.wait(OLD, "--follow-branch", "--within", "2")

    assert_equal "cancelled", FunCi::Persistence::PipelineRun.find(@agent.db, @old_run)[:status]
  end

  def test_should_cancel_a_run_nobody_is_waiting_on_when_a_newer_commit_starts
    @pipeline.trigger(commit_hash: NEW, branch: "main")

    assert_equal "cancelled", FunCi::Persistence::PipelineRun.find(@agent.db, @old_run)[:status]
  end

  def test_should_never_cancel_a_run_of_the_same_commit
    @pipeline.trigger(commit_hash: OLD, branch: "main")

    assert_equal "running", FunCi::Persistence::PipelineRun.find(@agent.db, @old_run)[:status]
  end

  def test_should_exit_superseded_naming_the_newer_commit
    @pipeline.trigger(commit_hash: NEW, branch: "main")

    assert_equal [4, "Superseded by bbb2222."], [@agent.wait(OLD), @agent.stdout.lines.last.chomp]
  end

  def test_should_follow_the_branch_to_the_newer_commit_s_run
    @pipeline.trigger(commit_hash: NEW, branch: "main")

    assert_equal 0, @agent.wait(OLD, "--follow-branch")
  end

  def test_should_print_only_the_answer_as_json_when_following_the_branch
    @pipeline.trigger(commit_hash: NEW, branch: "main")
    @agent.wait(OLD, "--follow-branch", "--json")

    assert_equal NEW, JSON.parse(@agent.stdout).dig("commit", "sha")
  end

  def test_should_say_it_followed_the_branch
    @pipeline.trigger(commit_hash: NEW, branch: "main")
    @agent.wait(OLD, "--follow-branch")

    assert_equal "fun-ci: aaa1111 was superseded; following main to bbb2222.", @agent.stdout.lines.first.chomp
  end
end
