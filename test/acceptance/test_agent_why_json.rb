# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require "json"

# `why --json` gives what `why` prints as one document (acceptance-tests.md, AT-10.2).
class TestAgentWhyJson < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  JUNIT = <<~XML
    <testsuite><testcase classname="FetchTest" name="retries" file="test/fetch_test.rb" line="41">
    <failure>boom</failure></testcase></testsuite>
  XML
  CONFIG = "evidence:\n  stages:\n    fast:\n      - use: junit-files\n        paths: [reports/*.xml]\n"

  def setup
    @pipeline = TriggerCliClient.open(command_runner: fast_suite_failing)
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main", config: CONFIG)
  end

  def teardown = @pipeline.close

  def test_should_give_the_fields_of_the_why_document
    @agent.why("--json")

    assert_equal %w[schema commit stage state exit_status signal seconds budget evidence no_evidence raw_output],
                 JSON.parse(@agent.stdout).keys
  end

  def test_should_say_how_the_stage_ended
    @agent.why("--json")

    assert_equal({ "stage" => "fast", "state" => "failed", "exit_status" => 1, "signal" => nil, "budget" => 10 },
                 JSON.parse(@agent.stdout).slice("stage", "state", "exit_status", "signal", "budget"))
  end

  def test_should_give_the_failures_each_naming_the_extractor_that_found_it
    @agent.why("--json")

    assert_equal [{ "file" => "test/fetch_test.rb", "line" => 41, "test" => "FetchTest#retries", "message" => "boom",
                    "extractor" => "junit-files" }],
                 JSON.parse(@agent.stdout).dig("evidence", "failures")
  end

  def test_should_exit_with_the_verdict
    assert_equal 1, @agent.why("--json")
  end

  def test_should_give_no_evidence_for_a_stage_that_passed
    @agent.why("--json", "lint")

    assert_equal [nil, "passed"], JSON.parse(@agent.stdout).values_at("evidence", "no_evidence")
  end

  private

  def fast_suite_failing
    lambda do |cmd|
      next ["", FakeStatus.new(true, 0)] unless cmd.include?("fast.sh")

      FileUtils.mkdir_p(File.join(@pipeline.project_dir, "reports"))
      File.write(File.join(@pipeline.project_dir, "reports", "TEST-FetchTest.xml"), JUNIT)
      ["the suite's own output\n", FakeStatus.new(false, 1)]
    end
  end
end
