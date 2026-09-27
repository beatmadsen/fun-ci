# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"

# `why` says when only the last lines were kept (acceptance-tests.md,
# AT-10.18), so an agent that reads it can write the extractor itself.
class TestAgentWhyOnlyTail < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"

  def setup
    runner = script_simulating_runner(failures: { "fast.sh" => { output: "boom\n" } })
    @pipeline = TriggerCliClient.open(command_runner: runner)
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main")
  end

  def teardown = @pipeline.close

  def test_should_end_by_saying_only_the_last_lines_were_kept_and_how_to_keep_more
    @agent.why

    assert_equal "Only the output's last lines were kept; extractors under `evidence:` in .fun-ci/config keep more.",
                 @agent.stdout.lines.last.chomp
  end
end
