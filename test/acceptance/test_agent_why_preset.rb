# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require_relative "../support/evidence_fixtures"
require "json"

# A preset picks out a tool's failures (acceptance-tests.md, AT-10.10): the
# fast suite prints the recorded failing rspec run, then 250 lines of a
# coverage report, so its failures are far above its last 200 lines.
class TestAgentWhyPreset < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  RSPEC = EvidenceFixtures.all.find { |fixture| fixture.name == "rspec" }.output
  OUTPUT = "#{RSPEC}#{(1..250).map { |n| "lib/file_#{n}.rb  100.0%\n" }.join}".freeze
  CONFIG = <<~YAML
    evidence:
      stages:
        fast:
          - use: section
            preset: rspec
  YAML

  def setup
    @pipeline = TriggerCliClient.open(command_runner: method(:fast_suite_failing))
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main", config: CONFIG)
    @agent.why("--json")
  end

  def teardown = @pipeline.close

  def test_should_keep_rspec_s_failures_section_under_the_preset_s_name
    assert_equal ["section:rspec", "output:3-29"], excerpt.values_at("extractor", "location")
  end

  def test_should_keep_the_lines_of_the_failures_section
    assert_equal RSPEC.lines(chomp: true)[2..28], excerpt["lines"]
  end

  private

  def excerpt = JSON.parse(@agent.stdout).dig("evidence", "excerpts").first

  def fast_suite_failing(cmd)
    cmd.include?("fast.sh") ? [OUTPUT, FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)]
  end
end
