# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"

# A slow suite waiting its branch's turn starts in one statement that a cancel
# of its run, recorded first, refuses: a newer commit either cancels it before
# it starts or leaves it to finish, never kills it once started (AT-9.19).
class TestStageJobStartedInTurn < Minitest::Test
  include DatabaseTestSetup

  RUN = FunCi::Persistence::PipelineRun
  JOB = FunCi::Persistence::StageJob

  def setup
    setup_test_db
    @run_id = RUN.create(@db, commit_hash: "abc1234", branch: "main", project_path: "/project")
    RUN.update_status(@db, @run_id, "running")
    @slow = JOB.create(@db, pipeline_run_id: @run_id, stage: "slow")
  end

  def teardown = teardown_test_db

  def test_should_record_a_waiting_slow_suite_running_when_its_turn_comes
    JOB.started_in_turn?(@db, @slow)

    assert_equal "running", JOB.find(@db, @slow)[:status]
  end

  def test_should_say_the_slow_suite_may_start_when_its_turn_comes
    assert JOB.started_in_turn?(@db, @slow)
  end

  def test_should_refuse_the_turn_of_a_slow_suite_whose_run_was_recorded_cancelled_while_it_waited
    RUN.update_status(@db, @run_id, "cancelled")

    refute JOB.started_in_turn?(@db, @slow)
  end

  def test_should_leave_waiting_a_slow_suite_whose_run_was_recorded_cancelled
    RUN.update_status(@db, @run_id, "cancelled")
    JOB.started_in_turn?(@db, @slow)

    assert_equal "scheduled", JOB.find(@db, @slow)[:status]
  end

  def test_should_refuse_the_turn_of_a_slow_suite_recorded_cancelled
    JOB.update_status(@db, @slow, "cancelled")

    refute JOB.started_in_turn?(@db, @slow)
  end
end
