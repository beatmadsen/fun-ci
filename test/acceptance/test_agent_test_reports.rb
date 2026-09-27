# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require "json"

# A stage's test reports name its failures (acceptance-tests.md, AT-9.7): a
# stage writes JUnit XML or fun-ci's JSON into the directory FUN_CI_REPORT
# names, and the agent reads the failures back.
class TestAgentTestReports < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
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

  def test_should_list_the_reported_failures_after_the_failed_stage
    run_fast_suite_writing("fast.xml" => JUNIT)

    @agent.status

    assert_equal ["fast failed:", "  test/unit/test_fetch.rb:41  FetchTest#test_retries_three_times",
                  "    Expected 3, got 1", "    test/unit/test_fetch.rb:41"], evidence
  end

  def test_should_read_fun_ci_s_own_json_report
    failure = { file: "lib/fetch.rb", line: 12, test: "lint: Style/Semicolon", message: "Don't use semicolons" }
    run_fast_suite_writing("lint.json" => JSON.generate(failures: [failure]))

    @agent.status

    assert_equal ["fast failed:", "  lib/fetch.rb:12  lint: Style/Semicolon", "    Don't use semicolons"], evidence
  end

  def test_should_give_the_failures_to_a_program
    run_fast_suite_writing("fast.xml" => JUNIT)

    @agent.status("--json")

    assert_equal [{ "file" => "test/unit/test_fetch.rb", "line" => 41, "test" => "FetchTest#test_retries_three_times",
                    "message" => "Expected 3, got 1\ntest/unit/test_fetch.rb:41" }],
                 JSON.parse(@agent.stdout)["stages"][2]["failures"]
  end

  def test_should_show_the_kept_output_when_the_report_cannot_be_read
    run_fast_suite_writing("fast.xml" => "<testsuite><testcase")

    @agent.status

    assert_equal ["fast failed:", "  the suite's own output"], evidence
  end

  private

  # The fast suite prints a line, writes each report file, and fails.
  def run_fast_suite_writing(files)
    runner = lambda do |cmd, env|
      next ["", FakeStatus.new(true, 0)] unless cmd.include?("fast.sh")

      files.each { |name, content| File.write(File.join(env.fetch("FUN_CI_REPORT"), name), content) }
      ["the suite's own output\n", FakeStatus.new(false, 1)]
    end
    start(runner)
  end

  def start(runner)
    @pipeline = TriggerCliClient.open(command_runner: runner)
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main")
  end

  def evidence = @agent.stdout.lines.map(&:chomp).drop(5)
end
