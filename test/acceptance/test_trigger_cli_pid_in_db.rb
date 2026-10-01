# frozen_string_literal: true

require_relative "trigger_cli_shared"

# Background process PIDs live in the pipeline_runs table, not in
# .fun-ci-pids/ files. test/integration/test_stale_pipeline_cancellation.rb
# shows the canceller reading them from there.
class TestTriggerCliPidInDb < Minitest::Test
  def setup
    @client = TriggerCliClient.open(command_runner: INSTANT_SUCCESS_RUNNER)
  end

  def teardown
    @client.close
  end

  def test_should_not_create_pid_files_on_filesystem
    @client.trigger(commit_hash: "abc1234", branch: "main")

    refute Dir.exist?(File.join(@client.project_dir, ".fun-ci-pids"))
  end

  # Its pid may be reused once it has gone, so a cancel must not signal it.
  def test_should_let_go_of_the_trigger_s_pid_when_its_stages_are_done
    @client.trigger(commit_hash: "abc1234", branch: "main")

    assert_nil @client.pipeline_runs_for(commit_hash: "abc1234").first[:trigger_pid]
  end
end
