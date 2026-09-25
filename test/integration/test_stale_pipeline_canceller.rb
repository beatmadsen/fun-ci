# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "fun_ci/pipeline/stale_pipeline_canceller"
require "fun_ci/persistence/database"

# A new commit on a branch cancels the runs still going for older ones. How
# a run's processes are stopped is RunCanceller's.
class TestStalePipelineCanceller < Minitest::Test
  include DatabaseTestSetup

  RUN = FunCi::Persistence::PipelineRun

  def setup
    setup_test_db
    @stdout = StringIO.new
    @stopped = []
  end

  def teardown = teardown_test_db

  def test_should_stop_every_unfinished_run_on_the_branch
    runs = [active_run("abc1234"), active_run("bcd2345")]
    cancel

    assert_equal runs, @stopped.map(&:id)
  end

  def test_should_record_a_stopped_run_cancelled
    run_id = active_run("abc1234")
    cancel

    assert_equal "cancelled", RUN.find(@db, run_id)[:status]
  end

  def test_should_say_which_run_it_cancelled_for_which_commit
    active_run("abc1234")
    cancel

    assert_equal "Cancelled stale pipeline for abc1234. Starting fresh for def5678.\n", @stdout.string
  end

  def test_should_leave_runs_on_other_branches_alone
    active_run("abc1234", branch: "feature")
    cancel

    assert_empty @stopped
  end

  def test_should_leave_finished_runs_alone
    RUN.update_status(@db, active_run("abc1234"), "completed")
    cancel

    assert_empty @stopped
  end

  private

  def active_run(sha, branch: "main")
    RUN.create(@db, commit_hash: sha, branch: branch).tap { |id| RUN.update_status(@db, id, "running") }
  end

  def cancel
    stopper = Struct.new(:stopped) { def stop(run) = stopped << run }.new(@stopped)
    FunCi::Pipeline::StalePipelineCanceller.new(db: @db, branch: "main", stdout: @stdout, run_canceller: stopper)
                                           .cancel(new_commit_hash: "def5678")
  end
end
