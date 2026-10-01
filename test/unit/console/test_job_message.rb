# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/console/job_message"

# A job row as the protocol's `board` carries it, under `jobs` (renderer-protocol.md, `board`).
class TestJobMessage < Minitest::Test
  # Where a job stands, as Jobs::Standing answers it.
  Standing = Data.define(:project, :name, :cadence, :state, :run, :due_at)

  STARTED = Time.utc(2026, 10, 1, 9)
  RUN = { id: 7, commit_hash: "a" * 40, branch: "main", status: "completed",
          started_at: "2026-10-01T09:00:00.000Z", completed_at: "2026-10-01T10:30:00.000Z" }.freeze

  def test_should_name_the_job_and_how_often_it_runs
    assert_equal %w[mutation daily], job_message(run: nil).values_at(:name, :cadence)
  end

  def test_should_carry_the_project_the_job_belongs_to
    assert_equal "/p", job_message(run: nil)[:project]
  end

  def test_should_say_passed_for_a_job_whose_run_completed
    assert_equal "passed", job_message(state: "passed")[:status]
  end

  def test_should_say_timeout_for_a_job_that_ran_out_of_time
    assert_equal "timeout", job_message(state: "over_budget")[:status]
  end

  # Its process died before it said how the run ended.
  def test_should_say_lost_for_a_failed_job_whose_run_has_no_end
    assert_equal "lost", job_message(state: "lost")[:status]
  end

  def test_should_say_due_for_a_job_whose_latest_run_was_cancelled
    assert_equal "due", job_message(state: "cancelled")[:status]
  end

  def test_should_say_due_for_a_job_whose_state_it_does_not_know
    assert_equal "due", job_message(state: "unknown")[:status]
  end

  def test_should_say_due_for_a_job_that_is_due
    assert_equal "due", job_message(state: "due", run: nil)[:status]
  end

  def test_should_carry_the_commit_and_branch_the_run_tested
    assert_equal ["a" * 40, "main"], job_message.values_at(:sha, :branch)
  end

  def test_should_carry_when_the_run_started_in_epoch_seconds
    assert_equal STARTED.to_i, job_message[:started_at]
  end

  def test_should_carry_when_the_run_ended_as_its_last_change
    assert_equal (STARTED + 5400).to_i, job_message[:updated_at]
  end

  def test_should_carry_when_a_running_job_started_as_its_last_change
    assert_equal STARTED.to_i, job_message(run: RUN.merge(completed_at: nil))[:updated_at]
  end

  def test_should_carry_the_run_s_id
    assert_equal 7, job_message[:run_id]
  end

  def test_should_carry_when_the_job_is_due_again
    assert_equal (STARTED + 86_400).to_i, job_message(due_at: STARTED + 86_400)[:due_at]
  end

  def test_should_leave_out_what_a_job_that_never_ran_lacks
    assert_equal %i[cadence name project status], job_message(state: "due", run: nil).keys.sort
  end

  private

  def job_message(state: "passed", run: RUN, due_at: nil)
    FunCi::Console::JobMessage.from(Standing.new(project: "/p", name: "mutation", cadence: "daily", state: state,
                                                 run: run, due_at: due_at))
  end
end
