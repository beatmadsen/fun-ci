# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "fun_ci/pipeline/stale_pipeline_canceller"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_runs"
require "fun_ci/persistence/job_recorder"
require "fun_ci/jobs/job"

# A new commit cancels the older runs on its branch, never a job that tests
# an older commit of it (acceptance-tests.md, AT-13.11).
class TestStaleCancellerLeavesJobs < Minitest::Test
  include DatabaseTestSetup

  SOAK = FunCi::Jobs::Job.new(name: "soak", cadence: "weekly", script: "/project/.fun-ci/weekly/soak.sh")

  def setup
    setup_test_db
    @signals = []
    runs = FunCi::Persistence::JobRuns.new(@db, "/project")
    @id = runs.claim(SOAK, commit: { sha: "abc1234", branch: "main" }, lock_file: "/l", now: Time.now)
    FunCi::Persistence::JobRecorder.new(@db).tap { |recorder| recorder.started_by(@id, 100) }
                                   .stage_process(@id, 200)
  end

  def teardown = teardown_test_db

  def test_should_stop_no_process_of_a_job_on_the_branch
    cancel

    assert_empty @signals
  end

  def test_should_leave_a_job_on_the_branch_running
    cancel

    assert_equal "running", FunCi::Persistence::JobRuns.new(@db, "/project").latest("soak")[:status]
  end

  private

  def cancel
    canceller = FunCi::Pipeline::RunCanceller.new(killer: ->(signal, pid) { @signals << [signal, pid] })
    main = FunCi::Persistence::Branch.new(project: "/project", name: "main")
    FunCi::Pipeline::StalePipelineCanceller.new(db: @db, branch: main, stdout: StringIO.new, run_canceller: canceller)
                                           .cancel(new_commit_hash: "def5678")
  end
end
