# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/db_recorder_setup"
require "fun_ci/persistence/run_status"

# AT-7.1: each stage's end settles the run's status from its stages alone.
class TestRunStatus < Minitest::Test
  include DbRecorderTestSetup

  def setup
    super
    create_run
  end

  def test_should_fail_the_run_when_a_stage_fails
    end_stages(lint: "failed")

    assert_equal "failed", run_status
  end

  def test_should_fail_the_run_when_a_stage_times_out
    end_stages(fast: "timed_out")

    assert_equal "failed", run_status
  end

  def test_should_keep_the_run_running_while_a_stage_has_not_passed
    end_stages(lint: "completed", build: "completed", slow: "completed")

    assert_equal "running", run_status
  end

  def test_should_complete_the_run_once_all_four_stages_passed
    end_stages(lint: "completed", build: "completed", slow: "completed", fast: "completed")

    assert_equal "completed", run_status
  end

  def test_should_keep_a_failed_run_failed_when_a_later_stage_passes
    end_stages(lint: "completed", build: "completed", fast: "failed", slow: "completed")

    assert_equal "failed", run_status
  end

  def test_should_keep_a_completed_run_completed_when_a_stage_fails_afterwards
    end_stages(lint: "completed", build: "completed", slow: "completed", fast: "completed")

    end_stages(fast: "failed")

    assert_equal "completed", run_status
  end

  def test_should_keep_a_cancelled_run_cancelled_when_a_stage_fails
    job_id = @recorder.start_stage("lint")
    FunCi::Persistence::PipelineRun.update_status(@db, @recorder.pipeline_run_id, "cancelled")

    @recorder.end_stage(job_id, "failed")

    assert_equal "cancelled", run_status
  end

  def test_should_leave_the_last_change_time_alone_when_the_status_stays_the_same
    FunCi::Persistence::PipelineRun.update_status(@db, @recorder.pipeline_run_id, "running")
    @db.execute("UPDATE pipeline_runs SET updated_at = '2000-01-01T00:00:00Z'")

    end_stages(lint: "completed")

    assert_equal "2000-01-01T00:00:00Z", last_change
  end

  private

  def last_change = FunCi::Persistence::PipelineRun.find(@db, @recorder.pipeline_run_id)[:updated_at]

  def end_stages(outcomes)
    outcomes.each { |stage, status| @recorder.end_stage(@recorder.start_stage(stage.to_s), status) }
  end
end
