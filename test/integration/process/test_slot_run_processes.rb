# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/process_deadline"
require_relative "../../support/body_script"
require "stringio"
require "tmpdir"
require "fun_ci/pipeline/slot_run"
require "fun_ci/pipeline/slot"
require "fun_ci/setup/project_config"
require "fun_ci/pipeline/priorities"

# The contract with a project's stage scripts, run as real processes in the
# slot a pipeline was given (AT-1.1): each runs there, gets the commit hash
# as $1, and its exit status decides pass or fail. Worktrees makes the slot a
# checkout of the commit (test_worktrees); what `fun-ci trigger` does before
# and after is pinned in the acceptance lane.
class TestSlotRunProcesses < Minitest::Test
  include ProcessDeadline

  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  STAGES = %w[lint build fast slow].freeze
  Lock = Struct.new(:closed?) do
    def close = self[:closed?] = true
  end

  def setup
    @slot = File.realpath(Dir.mktmpdir("slot"))
    @record = Dir.mktmpdir("record")
    @stdout = StringIO.new
  end

  def teardown = FileUtils.rm_rf([@slot, @record])

  def test_should_give_every_stage_script_the_commit_hash
    run_stages { |stage| %(echo "$1" > #{@record}/#{stage}) }

    assert_equal [SHA] * 4, recorded
  end

  def test_should_run_every_stage_script_in_the_slot
    run_stages { |stage| %(pwd -P > #{@record}/#{stage}) }

    assert_equal [@slot] * 4, recorded
  end

  def test_should_fail_when_a_script_exits_other_than_zero
    assert_equal(1, run_stages { |stage| stage == "build" ? "exit 3" : "true" })
  end

  def test_should_say_which_stage_failed
    run_stages { |stage| stage == "build" ? "exit 3" : "true" }

    assert_includes @stdout.string, "Build failed."
  end

  def test_should_pass_when_every_script_exits_zero
    assert_equal(0, run_stages { |_stage| "true" })
  end

  # So it gives way to the fast suite beside it (AT-13.27).
  def test_should_run_the_slow_suite_at_the_slow_priority
    run_stages(slow_priority: "nice -n 7 ") { |stage| %(echo $(ps -o nice= -p $$) > #{@record}/#{stage}) }

    assert_equal "7", recorded.last
  end

  def test_should_run_the_fast_suite_at_the_priority_fun_ci_runs_at
    run_stages(slow_priority: "nice -n 7 ") { |stage| %(echo $(ps -o nice= -p $$) > #{@record}/#{stage}) }

    assert_equal Process.getpriority(Process::PRIO_PROCESS, 0).to_s, recorded[2]
  end

  private

  def recorded = STAGES.map { |stage| File.read(File.join(@record, stage)).chomp }

  # Writes each stage's script from the block, and runs the pipeline with the slow suite inline.
  def run_stages(slow_priority: "")
    STAGES.each { |stage| write_script(stage, yield(stage)) }
    within_deadline { slot_run(slow_priority).run(FunCi::Setup::ProjectConfig.new(@slot)) }
  end

  def write_script(stage, body) = BodyScript.write(File.join(@slot, ".fun-ci", "#{stage}.sh"), body)

  def slot_run(slow_priority)
    launcher = ->(job_id:, executor:, **) { executor.call(FakeRecorder.new, job_id) }
    seams = FunCi::Pipeline::Seams.new(recorder: FakeRecorder.new, background_launcher: launcher,
                                       priorities: FunCi::Pipeline::Priorities.new(job: "", slow: slow_priority))
    FunCi::Pipeline::SlotRun.new(commit: FunCi::Pipeline::Commit.new(sha: SHA, branch: "main"),
                                 io: FunCi::Pipeline::Io.new(stdout: @stdout, stderr: @stdout), seams: seams,
                                 slot: FunCi::Pipeline::Slot.new(@slot, Lock.new(false)))
  end
end
