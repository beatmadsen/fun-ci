# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"

# The digest in `status` and `wait` names the `why` command
# (acceptance-tests.md, AT-10.4).
class TestAgentDigestNamesWhy < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"

  def setup
    @pipeline = TriggerCliClient.open(command_runner: script_simulating_runner(failures: { "fast.sh" => {} }))
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main")
  end

  def teardown = @pipeline.close

  def test_should_end_status_with_the_why_command
    @agent.status

    assert_equal "fun-ci why 3f9c2ab fast", @agent.stdout.lines.last.chomp
  end

  def test_should_end_wait_with_the_why_command
    @agent.wait

    assert_equal "fun-ci why 3f9c2ab fast", @agent.stdout.lines.last.chomp
  end
end
