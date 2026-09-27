# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require_relative "../support/evidence_fixtures"
require "json"

# json-log keeps structured log records at or above a level
# (acceptance-tests.md, AT-10.13): the fast suite prints the recorded run of
# an app logging through logstash-logback-encoder, plain lines among its JSON.
class TestAgentWhyJsonLog < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  FIXTURE = EvidenceFixtures.all.find { |fixture| fixture.name == "logstash" }
  CONFIG = <<~YAML
    evidence:
      stages:
        fast:
          - use: json-log
            preset: logstash
            level: warn
  YAML

  def setup
    @pipeline = TriggerCliClient.open(command_runner: method(:fast_suite_failing))
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main", config: CONFIG)
    @agent.why("--json")
  end

  def teardown = @pipeline.close

  def test_should_keep_a_line_per_warn_and_error_record_each_followed_by_its_stack_trace
    assert_equal FIXTURE.expected.fetch("lines"), excerpt["lines"]
  end

  def test_should_credit_them_to_the_preset
    assert_equal "json-log:logstash", excerpt["extractor"]
  end

  private

  def excerpt = JSON.parse(@agent.stdout).dig("evidence", "excerpts").first

  def fast_suite_failing(cmd, &)
    cmd.include?("fast.sh") ? [FIXTURE.output, FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)]
  end
end
