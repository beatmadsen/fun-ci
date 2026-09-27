# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require "fun_ci/setup/setup_checker"
require "json"

# A mistake in the evidence configuration is reported, and only that entry
# is left out (acceptance-tests.md, AT-10.9).
class TestAgentWhyConfigMistake < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  CONFIG = <<~YAML
    evidence:
      stages:
        fast:
          - use: grep
            patterns: ["ERROR"]
          - use: nosuch
  YAML

  def setup
    @pipeline = TriggerCliClient.open(command_runner: method(:fast_suite_failing))
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main", config: CONFIG)
  end

  def teardown = @pipeline.close

  def test_should_name_the_unknown_extractor_in_check
    stdout = StringIO.new
    FunCi::Setup::SetupChecker.run(project_root: @pipeline.project_dir, stdout: stdout)

    assert_includes stdout.string, "evidence.stages.fast: unknown extractor 'nosuch'"
  end

  def test_should_keep_the_evidence_of_the_entries_without_a_mistake
    @agent.why("--json")

    assert_equal(%w[grep output-tail], JSON.parse(@agent.stdout).dig("evidence", "excerpts").map { |e| e["extractor"] })
  end

  def test_should_record_the_mistaken_entry_as_a_problem
    @agent.why

    assert_includes @agent.stdout, "  nosuch: unknown extractor 'nosuch'\n"
  end

  def test_should_leave_the_stage_s_verdict_as_it_was
    assert_equal 1, @agent.why
  end

  private

  def fast_suite_failing(cmd)
    cmd.include?("fast.sh") ? ["ERROR boom\n", FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)]
  end
end
