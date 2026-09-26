# frozen_string_literal: true

require_relative "trigger_cli_shared"

# A newer commit on a branch cancels the older run still going there: the
# latest commit wins (design.md, The pipeline).
class TestTriggerCancelsStaleRuns < Minitest::Test
  def setup
    @client = TriggerCliClient.open(command_runner: INSTANT_SUCCESS_RUNNER)
  end

  def teardown
    @client.close
  end

  def test_should_cancel_the_unfinished_run_on_the_same_branch_when_a_newer_commit_triggers
    older = unfinished_run(branch: "main")

    @client.trigger(commit_hash: "abc1234", branch: "main")

    assert_equal "cancelled", FunCi::Persistence::PipelineRun.find(@client.db, older)[:status]
  end

  def test_should_say_which_run_it_cancelled_for_which_when_it_cancels_one
    unfinished_run(branch: "main")

    @client.trigger(commit_hash: "abc1234", branch: "main")

    assert_includes @client.stdout, "Cancelled stale pipeline for old5678. Starting fresh for abc1234."
  end

  def test_should_leave_an_unfinished_run_alone_when_it_is_on_another_branch
    other = unfinished_run(branch: "feature")

    @client.trigger(commit_hash: "abc1234", branch: "main")

    assert_equal "running", FunCi::Persistence::PipelineRun.find(@client.db, other)[:status]
  end

  private

  def unfinished_run(branch:)
    id = FunCi::Persistence::PipelineRun.create(@client.db, commit_hash: "old5678", branch: branch)
    FunCi::Persistence::PipelineRun.update_status(@client.db, id, "running")
    id
  end
end
