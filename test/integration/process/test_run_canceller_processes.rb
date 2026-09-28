# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/process_deadline"
require_relative "../../support/lifeline"
require_relative "../../support/fifo"
require "tmpdir"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_recorder"
require "fun_ci/persistence/active_runs"
require "fun_ci/pipeline/run_canceller"

# Cancelling a run stops its real processes (AT-1.6, AT-1.12): its forked
# slow suite, and every process of each stage's group, recorded as a
# pipeline records them. Who cancels which run is BoardData's and
# StalePipelineCanceller's (their integration tests); a slot whose holders
# die is free again (test_crashed_run_slot).
class TestRunCancellerProcesses < Minitest::Test
  include DatabaseTestSetup
  include ProcessDeadline

  def setup
    setup_test_db
    recorder = FunCi::Persistence::DbRecorder.new(@db)
    run_id = recorder.create_run(commit_hash: "abc1234", branch: "main", project_path: "/project")
    stage = start_stage_group(recorder)
    slow = start_slow_suite(run_id)
    FunCi::Persistence::ActiveRuns.with_id(@db, run_id).each { |run| FunCi::Pipeline::RunCanceller.new.cancel(@db, run) }
    @slow_status = within_deadline { Process.wait(stage) && Process.wait2(slow).last }
  end

  def teardown
    @lifeline&.close
    teardown_test_db
  end

  def test_should_stop_a_process_a_stage_started
    assert(within_deadline { @lifeline.all_ended? })
  end

  def test_should_stop_the_forked_slow_suite
    assert_equal "KILL", Signal.signame(@slow_status.termsig)
  end

  def test_should_record_the_run_cancelled
    assert_equal "cancelled", FunCi::Persistence::PipelineRun.find_by_commit(@db, "abc1234").first[:status]
  end

  private

  # The run's forked slow suite, recorded as BackgroundFork records it.
  def start_slow_suite(run_id)
    Process.spawn("sleep", "30").tap { |pid| FunCi::Persistence::PipelineRun.store_pid(@db, run_id, pid) }
  end

  # A stage whose script starts a child, in a process group of its own, as
  # ProcessRunner starts one; both hold the lifeline. The child outlives any
  # deadline unless it is killed.
  def start_stage_group(recorder)
    @lifeline = Lifeline.new(@dir)
    started = File.join(@dir, "started").tap { |fifo| File.mkfifo(fifo) }
    script = "#{@lifeline.hold}; sleep 300 & echo $! > #{started}; wait"
    pid = Process.spawn("sh", "-c", script, pgroup: true, %i[out err] => File::NULL)
    recorder.stage_process(recorder.start_stage("fast"), pid)
    Fifo.read(started)
    pid
  end
end
