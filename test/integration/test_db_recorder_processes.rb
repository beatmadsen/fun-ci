# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/db_recorder_setup"

# What DbRecorder notes so that a run can be cancelled: the processes it runs
# in and the lock of the slot it holds.
class TestDbRecorderProcesses < Minitest::Test
  include DbRecorderTestSetup

  def test_should_record_the_process_running_the_pipeline
    create_run

    assert_equal Process.pid, @db.execute("SELECT trigger_pid FROM pipeline_runs").dig(0, 0)
  end

  def test_should_record_the_lock_of_the_slot_the_run_took
    create_run
    @recorder.slot_taken("/worktrees/slot-0.lock")

    assert_equal "/worktrees/slot-0.lock", @db.execute("SELECT slot_lock FROM pipeline_runs").dig(0, 0)
  end

  def test_should_forget_the_trigger_process_once_the_foreground_is_done
    create_run
    @recorder.foreground_done

    assert_nil @db.execute("SELECT trigger_pid FROM pipeline_runs").dig(0, 0)
  end

  def test_should_record_the_process_a_stage_runs_in
    create_run
    @recorder.stage_process(@recorder.start_stage("lint"), 4242)

    assert_equal 4242, @db.execute("SELECT pid FROM stage_jobs").dig(0, 0)
  end
end
