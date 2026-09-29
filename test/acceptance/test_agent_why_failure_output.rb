# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"

# A failure keeps its own output (acceptance-tests.md, AT-10.14).
class TestAgentWhyFailureOutput < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  JUNIT = <<~XML
    <testsuite name="CartTest" tests="1" failures="1">
      <testcase classname="CartTest" name="adds" file="CartTest.java" line="13">
        <failure message="expected 5 but was 6">expected 5 but was 6</failure>
        <system-out>total so far: 6
    applying rounding</system-out>
      </testcase>
    </testsuite>
  XML

  CONFIG = "evidence:\n  stages:\n    fast:\n      - use: junit-files\n        paths: [reports/*.xml]\n"

  def setup
    @pipeline = TriggerCliClient.open(command_runner: method(:fast_suite_reporting))
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main", config: CONFIG)
    @agent.why
  end

  def teardown = @pipeline.close

  def test_should_print_the_failure_s_own_output_under_its_message
    assert_includes @agent.stdout,
                    "    expected 5 but was 6\n    Output:\n      total so far: 6\n      applying rounding\n"
  end

  private

  def fast_suite_reporting(cmd, &)
    return ["", FakeStatus.new(true, 0)] unless cmd.include?("fast.sh")

    FileUtils.mkdir_p(File.join(@pipeline.project_dir, "reports"))
    File.write(File.join(@pipeline.project_dir, "reports", "TEST-CartTest.xml"), JUNIT)
    ["", FakeStatus.new(false, 1)]
  end
end
