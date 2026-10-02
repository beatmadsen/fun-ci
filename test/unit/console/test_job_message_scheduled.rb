# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/console/job_message"

# A job waiting its turn to start (Jobs::Schedule) as the protocol's `board`
# carries it (renderer-protocol.md, `board`; AT-13.28): when it starts, and
# no start or change of its run, which has not begun.
class TestJobMessageScheduled < Minitest::Test
  Standing = Data.define(:project, :name, :cadence, :state, :run, :due_at, :starts_at)

  STARTS = Time.utc(2026, 10, 2, 12, 10)
  RUN = { id: 8, commit_hash: "b" * 40, branch: "main", status: "scheduled", started_at: "2026-10-02T12:10:00.000Z",
          completed_at: nil }.freeze

  def test_should_say_a_job_waiting_its_turn_is_scheduled
    assert_equal "scheduled", job_message[:status]
  end

  def test_should_carry_when_a_job_waiting_its_turn_starts_in_epoch_seconds
    assert_equal STARTS.to_i, job_message[:starts_at]
  end

  def test_should_carry_no_start_for_a_run_that_has_not_begun
    refute_includes job_message.keys, :started_at
  end

  def test_should_carry_no_last_change_for_a_run_that_has_not_begun
    refute_includes job_message.keys, :updated_at
  end

  private

  def job_message
    FunCi::Console::JobMessage.from(Standing.new(project: "/p", name: "soak", cadence: "weekly", state: "scheduled",
                                                 run: RUN, due_at: nil, starts_at: STARTS))
  end
end
