# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"

# `fun-ci why` prints everything kept about a failed stage
# (acceptance-tests.md, AT-10.1): the pipeline keeps the failures a failed
# fast suite's JUnit report names and the end of its output, and the agent
# reads it all.
class TestAgentWhy < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  OUTPUT = (1..250).map { |n| "line #{n}\n" }.join
  MESSAGE = (1..7).map { |n| "detail #{n}" }.join("\n")
  JUNIT = <<~XML.freeze
    <testsuite><testcase classname="FetchTest" name="retries" file="test/fetch_test.rb" line="41">
    <failure>#{MESSAGE}</failure></testcase></testsuite>
  XML
  CONFIG = "evidence:\n  stages:\n    fast:\n      - use: junit-files\n        paths: [reports/*.xml]\n"

  def setup
    @pipeline = TriggerCliClient.open(command_runner: fast_suite_failing)
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main", config: CONFIG)
  end

  def teardown = @pipeline.close

  def test_should_start_with_the_stage_its_state_exit_status_time_and_budget
    @agent.why

    assert_match(/\Afast failed \(exit 1\) after \d+\.\ds, budget 10s\z/, @agent.stdout.lines[1].chomp)
  end

  def test_should_print_each_reported_failure_with_its_whole_message
    @agent.why

    assert_includes @agent.stdout, "  test/fetch_test.rb:41  FetchTest#retries\n#{MESSAGE.gsub(/^/, "    ")}\n"
  end

  def test_should_print_the_whole_kept_tail
    @agent.why

    assert_includes @agent.stdout, (51..250).map { |n| "  line #{n}\n" }.join
  end

  def test_should_exit_with_the_verdict
    assert_equal 1, @agent.why
  end

  def test_should_answer_for_the_stage_named
    @agent.why("HEAD", "lint")

    assert_match(/\Alint passed\b/, @agent.stdout.lines[1])
  end

  private

  def fast_suite_failing
    lambda do |cmd|
      next ["", FakeStatus.new(true, 0)] unless cmd.include?("fast.sh")

      FileUtils.mkdir_p(File.join(@pipeline.project_dir, "reports"))
      File.write(File.join(@pipeline.project_dir, "reports", "TEST-FetchTest.xml"), JUNIT)
      [OUTPUT, FakeStatus.new(false, 1)]
    end
  end
end
