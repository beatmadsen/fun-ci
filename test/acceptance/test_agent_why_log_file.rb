# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require "json"

# A log file is read from where the stage started writing
# (acceptance-tests.md, AT-10.11): the slot's log/test.log still holds a
# previous run's lines, which are not this failure's evidence.
class TestAgentWhyLogFile < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  CONFIG = <<~YAML
    evidence:
      stages:
        fast:
          - use: log-file
            path: log/test.log
  YAML

  def setup
    @pipeline = TriggerCliClient.open(command_runner: method(:fast_suite_appending_to_its_log))
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    FileUtils.mkdir_p(File.join(@pipeline.project_dir, "log"))
    File.write(log, "previous run: all fine\n")
    @pipeline.trigger(commit_hash: SHA, branch: "main", config: CONFIG)
    @agent.why("--json")
  end

  def teardown = @pipeline.close

  def test_should_keep_only_the_lines_appended_during_the_stage
    assert_equal ["this run: connecting", "this run: ERROR connection refused"], excerpt["lines"]
  end

  def test_should_credit_them_to_log_file
    assert_equal "log-file", excerpt["extractor"]
  end

  private

  def log = File.join(@pipeline.project_dir, "log", "test.log")
  def excerpt = JSON.parse(@agent.stdout).dig("evidence", "excerpts").first

  def fast_suite_appending_to_its_log(cmd, &)
    return ["", FakeStatus.new(true, 0)] unless cmd.include?("fast.sh")

    File.write(log, "this run: connecting\nthis run: ERROR connection refused\n", mode: "a")
    ["", FakeStatus.new(false, 1)]
  end
end
