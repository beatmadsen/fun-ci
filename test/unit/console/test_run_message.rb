# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/console/run_message"

# AT-2.2: a run as BoardData reads it from SQLite, as the `board` message
# carries it (renderer-protocol.md): protocol status names, epoch seconds,
# milliseconds and the full SHA.
class TestRunMessage < Minitest::Test
  SHA = "d699a825065b037ba0b531e6405a5fa7a9c5326b"

  def run_row(**changes)
    { id: 7, commit_hash: SHA, branch: "main", status: "completed", project_path: "/src/app",
      created_at: "2026-09-25T10:00:00Z", updated_at: "2026-09-25T10:01:00Z", stages: [] }.merge(changes)
  end

  def stage_row(**changes)
    { stage: "fast", status: "completed", duration: 1.8, started_at: "2026-09-25T10:00:30Z" }.merge(changes)
  end

  def run_message(**changes) = FunCi::Console::RunMessage.from(run_row(**changes))
  def stage_message(**changes) = run_message(stages: [stage_row(**changes)])[:stages].first

  def test_should_carry_the_full_sha
    assert_equal SHA, run_message[:sha]
  end

  def test_should_carry_the_project_path
    assert_equal "/src/app", run_message[:project]
  end

  def test_should_leave_out_the_project_when_the_run_has_none
    refute run_message(project_path: nil).key?(:project)
  end

  def test_should_give_times_as_epoch_seconds
    assert_equal Time.utc(2026, 9, 25, 10, 1).to_i, run_message[:updated_at]
  end

  def test_should_start_the_run_when_it_was_created
    assert_equal Time.utc(2026, 9, 25, 10).to_i, run_message[:started_at]
  end

  def test_should_call_a_completed_run_passed
    assert_equal "passed", run_message[:status]
  end

  def test_should_call_a_scheduled_run_pending
    assert_equal "pending", run_message(status: "scheduled")[:status]
  end

  def test_should_call_a_timed_out_run_timeout
    assert_equal "timeout", run_message(status: "timed_out")[:status]
  end

  def test_should_keep_the_other_run_statuses
    assert_equal "cancelled", run_message(status: "cancelled")[:status]
  end

  def test_should_call_a_scheduled_stage_pending
    assert_equal "pending", stage_message(status: "scheduled")[:status]
  end

  def test_should_give_a_finished_stage_s_duration_in_milliseconds
    assert_equal 1800, stage_message[:duration_ms]
  end

  def test_should_give_a_running_stage_its_start
    assert_equal Time.utc(2026, 9, 25, 10, 0, 30).to_i, stage_message(status: "running", duration: nil)[:started_at]
  end

  def test_should_leave_the_start_off_a_finished_stage
    refute stage_message.key?(:started_at)
  end

  def test_should_leave_the_duration_off_a_stage_that_has_none
    refute stage_message(status: "scheduled", duration: nil, started_at: nil).key?(:duration_ms)
  end
end
