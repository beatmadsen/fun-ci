# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require "fun_ci/evidence/process_table"

# An overrun says what it was doing (acceptance-tests.md, AT-10.17): before
# the kill, process-tree records the deepest process still running.
class TestAgentWhyOverrun < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  ROW = FunCi::Evidence::ProcessTable::Row
  PROCESSES = [
    ROW.new(pid: 4242, ppid: 1, pgid: 4242, seconds: 10, command: "/bin/sh .fun-ci/fast.sh 3f9c2ab"),
    ROW.new(pid: 4250, ppid: 4242, pgid: 4242, seconds: 9.8, command: "java -cp build GradleWorkerMain"),
    ROW.new(pid: 5000, ppid: 1, pgid: 5000, seconds: 300, command: "vim notes.txt")
  ].freeze

  def setup
    @pipeline = TriggerCliClient.open(command_runner: method(:fast_suite_stuck), process_table: -> { PROCESSES })
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main")
  end

  def teardown = @pipeline.close

  def test_should_record_the_deepest_process_still_running
    @agent.why

    assert_includes @agent.stdout, "  running: java -cp build GradleWorkerMain (9.8s)\n"
  end

  def test_should_lead_the_digest_with_what_the_stage_was_running
    @agent.status

    assert_equal "fast ran over budget: running java -cp build GradleWorkerMain (9.8s)", @agent.stdout.lines[5].chomp
  end

  private

  def fast_suite_stuck(cmd, &on_start)
    return ["", FakeStatus.new(true, 0)] unless cmd.include?("fast.sh")

    on_start&.call(4242)
    raise Timeout::Error
  end
end
