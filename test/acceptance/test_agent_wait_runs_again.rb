# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require "json"

# A plain wait whose run a newer commit superseded runs the commit again,
# once: the agent asked about that commit (acceptance-tests.md, AT-9.21).
class TestAgentWaitRunsAgain < Minitest::Test
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

  def test_should_run_a_superseded_commit_again
    @pipeline.trigger(commit_hash: NEW, branch: "main")
    @agent.clock.then_do { @agent.record_run(OLD, stages: PASSED_TO_FAST) }
    @agent.wait(OLD, "--need", "fast")

    assert_equal [[OLD, "main"]], @agent.pipeline.started
  end

  def test_should_answer_for_the_commit_s_run_again
    @pipeline.trigger(commit_hash: NEW, branch: "main")
    @agent.clock.then_do { @agent.record_run(OLD, stages: PASSED_TO_FAST) }

    assert_equal 0, @agent.wait(OLD, "--need", "fast")
  end

  def test_should_say_it_runs_a_superseded_commit_again
    @pipeline.trigger(commit_hash: NEW, branch: "main")
    @agent.clock.then_do { @agent.record_run(OLD, stages: PASSED_TO_FAST) }
    @agent.wait(OLD, "--need", "fast")

    assert_equal "fun-ci: aaa1111 was superseded by bbb2222; running it again.", @agent.stdout.lines.first.chomp
  end

  def test_should_print_only_the_answer_as_json_when_running_a_commit_again
    @pipeline.trigger(commit_hash: NEW, branch: "main")
    @agent.clock.then_do { @agent.record_run(OLD, stages: PASSED_TO_FAST) }
    @agent.wait(OLD, "--need", "fast", "--json")

    assert_equal "passed", JSON.parse(@agent.stdout)["verdict"]
  end

  # The same 5 seconds a commit with no run gets for one to turn up (AT-9.11).
  def test_should_give_the_commit_s_run_again_five_seconds_to_turn_up
    @pipeline.trigger(commit_hash: NEW, branch: "main")
    @agent.wait(OLD)

    assert_equal 5, @agent.clock.pauses
  end

  def test_should_run_a_commit_again_only_once
    @pipeline.trigger(commit_hash: NEW, branch: "main")
    @agent.clock.then_do { cancelled(@agent.record_run(OLD)) }

    assert_equal [4, [[OLD, "main"]]], [@agent.wait(OLD), @agent.pipeline.started]
  end

  def test_should_exit_superseded_naming_the_newer_commit_when_its_run_again_never_turns_up
    @pipeline.trigger(commit_hash: NEW, branch: "main")

    assert_equal [4, "Superseded by bbb2222."], [@agent.wait(OLD), @agent.stdout.lines.last.chomp]
  end

  def test_should_exit_superseded_when_the_project_cannot_run_the_commit_again
    @pipeline.trigger(commit_hash: NEW, branch: "main")
    @agent.pipeline.set_up = false

    assert_equal 4, @agent.wait(OLD)
  end

  # Cancelled with no newer commit, by the console or `cancel`: the user meant it.
  def test_should_not_run_again_a_commit_cancelled_with_no_newer_commit_on_the_branch
    cancelled(@old_run)
    @agent.wait(OLD)

    assert_empty @agent.pipeline.started
  end

  private

  def cancelled(run_id) = FunCi::Persistence::PipelineRun.update_status(@agent.db, run_id, "cancelled")
end
