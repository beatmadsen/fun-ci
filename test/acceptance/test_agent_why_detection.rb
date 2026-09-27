# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require_relative "../support/evidence_fixtures"
require "json"

# fun-ci runs the presets that apply, and only those (acceptance-tests.md,
# AT-10.19): a project with a Gemfile and no evidence configuration, whose
# fast suite prints rspec's rerun lines.
class TestAgentWhyDetection < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  RSPEC = EvidenceFixtures.all.find { |fixture| fixture.name == "rspec" }.output

  def setup
    @pipeline = TriggerCliClient.open(command_runner: method(:fast_suite_failing))
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    File.write(File.join(@pipeline.project_dir, "Gemfile"), "source \"https://rubygems.org\"\n")
    @pipeline.trigger(commit_hash: SHA, branch: "main")
    @agent.why("--json")
  end

  def teardown = @pipeline.close

  def test_should_run_the_rspec_preset_because_of_the_gemfile_and_the_rerun_lines
    assert_equal({ "extractor" => "section:rspec", "because" => "file Gemfile, output matched \"rspec ./\"" },
                 chosen.find { |choice| choice["extractor"] == "section:rspec" })
  end

  def test_should_not_run_the_gradle_preset_whose_markers_are_missing
    assert_nil(chosen.find { |choice| choice["extractor"] == "section:gradle" })
  end

  private

  def chosen = JSON.parse(@agent.stdout).dig("evidence", "chosen")

  def fast_suite_failing(cmd, &)
    cmd.include?("fast.sh") ? [RSPEC, FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)]
  end
end
