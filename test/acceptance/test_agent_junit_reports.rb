# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require "json"

# A stage's JUnit reports name its failures (acceptance-tests.md, AT-9.7): the
# fast suite writes JUnit XML where its build keeps it, a `junit-files` entry
# reads it, and the agent reads the failures back.
class TestAgentJunitReports < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  CONFIG = <<~YAML
    evidence:
      stages:
        fast:
          - use: junit-files
            paths: [build/test-results/*.xml]
  YAML
  JUNIT = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <testsuite name="FetchTest" tests="2" failures="1">
      <testcase classname="FetchTest" name="test_retries_three_times" file="test/unit/test_fetch.rb" line="41">
        <failure message="Expected 3, got 1" type="Minitest::Assertion">Expected 3, got 1
    test/unit/test_fetch.rb:41</failure>
      </testcase>
      <testcase classname="FetchTest" name="test_gives_up" file="test/unit/test_fetch.rb" line="58"/>
    </testsuite>
  XML

  def teardown = @pipeline.close

  def test_should_list_the_failures_after_the_failed_stage
    run_fast_suite_writing(JUNIT)

    @agent.status

    assert_equal ["fast failed:", "  test/unit/test_fetch.rb:41  FetchTest#test_retries_three_times",
                  "    Expected 3, got 1", "    test/unit/test_fetch.rb:41"], evidence
  end

  def test_should_give_the_failures_to_a_program
    run_fast_suite_writing(JUNIT)

    @agent.status("--json")

    assert_equal [{ "file" => "test/unit/test_fetch.rb", "line" => 41, "test" => "FetchTest#test_retries_three_times",
                    "message" => "Expected 3, got 1\ntest/unit/test_fetch.rb:41" }],
                 JSON.parse(@agent.stdout)["stages"][2]["failures"]
  end

  def test_should_show_the_kept_output_when_the_report_cannot_be_read
    run_fast_suite_writing("<testsuite><testcase")

    @agent.status

    assert_equal ["fast failed:", "  the suite's own output"], evidence
  end

  private

  # The fast suite prints a line, writes its report, and fails.
  def run_fast_suite_writing(report)
    runner = lambda do |cmd, _env|
      next ["", FakeStatus.new(true, 0)] unless cmd.include?("fast.sh")

      FileUtils.mkdir_p(File.join(@pipeline.project_dir, "build/test-results"))
      File.write(File.join(@pipeline.project_dir, "build/test-results/TEST-FetchTest.xml"), report)
      ["the suite's own output\n", FakeStatus.new(false, 1)]
    end
    start(runner)
  end

  def start(runner)
    @pipeline = TriggerCliClient.open(command_runner: runner)
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main", config: CONFIG)
  end

  # Between the stage lines and the closing `fun-ci why` command.
  def evidence = @agent.stdout.lines.map(&:chomp)[5...-1]
end
