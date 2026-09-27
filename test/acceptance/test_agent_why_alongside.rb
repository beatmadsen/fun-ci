# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"

# The evidence says when another stage shared the worktree
# (acceptance-tests.md, AT-10.12): the slow suite is still running in the
# slot when the fast suite fails.
class TestAgentWhyAlongside < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"

  def setup
    @pipeline = TriggerCliClient.open(command_runner: script_simulating_runner(failures: { "fast.sh" => {} }),
                                      background_launcher: ->(**) {})
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main")
  end

  def teardown = @pipeline.close

  def test_should_name_the_slow_suite_as_running_alongside_the_fast_suite
    @agent.why("HEAD", "fast")

    assert_includes @agent.stdout, "Facts:\n  alongside: slow\n"
  end
end
