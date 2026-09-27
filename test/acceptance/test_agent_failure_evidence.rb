# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"

# `status` shows why a needed stage failed (acceptance-tests.md, AT-9.5,
# AT-9.6): the pipeline keeps the end of the failed stage's output, and the
# agent reads it back.
class TestAgentFailureEvidence < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  OUTPUT = (1..250).map { |n| "\e[31mline #{n}\e[0m\n" }.join

  def setup
    runner = script_simulating_runner(failures: { "fast.sh" => { output: OUTPUT } })
    @pipeline = TriggerCliClient.open(command_runner: runner)
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main")
  end

  def teardown = @pipeline.close

  def test_should_follow_the_stages_with_the_failed_stage_s_last_lines_without_colour
    @agent.status

    assert_equal ["fast failed:", *(231..250).map { |n| "  line #{n}" }], @agent.stdout.lines.map(&:chomp)[5...-1]
  end
end
