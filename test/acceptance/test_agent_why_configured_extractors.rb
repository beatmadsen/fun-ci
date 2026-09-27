# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"

# A stage's configured extractors run when it fails, the slow suite's too
# (acceptance-tests.md, AT-10.8).
class TestAgentWhyConfiguredExtractors < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  CONFIG = <<~YAML
    evidence:
      stages:
        slow:
          - use: grep
            patterns: ["ERROR"]
  YAML
  OUTPUT = "starting\nERROR: connection refused\n#{(1..300).map { |n| "line #{n}\n" }.join}".freeze

  def setup
    @pipeline = TriggerCliClient.open(command_runner: slow_suite_failing, background_launcher: SYNC_LAUNCHER)
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main", config: CONFIG)
    @agent.why("--need", "all")
  end

  def teardown = @pipeline.close

  def test_should_show_the_matching_line_under_grep
    assert_includes @agent.stdout, "from grep:\n  ERROR: connection refused\n"
  end

  def test_should_show_the_grep_excerpt_before_the_output_tail
    assert_operator @agent.stdout.index("from grep:"), :<, @agent.stdout.index("from output-tail:")
  end

  private

  def slow_suite_failing
    ->(cmd) { cmd.include?("slow.sh") ? [OUTPUT, FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)] }
  end
end
