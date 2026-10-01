# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/agent/live_pipeline"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_runs"
require "fun_ci/jobs/job"

# What `wait` and `events --follow` look for on each poll: processes that
# died without recording how their work ended (acceptance-tests.md, AT-8.3, AT-13.6).
class TestLivePipelineWatch < Minitest::Test
  include DatabaseTestSetup

  SOAK = FunCi::Jobs::Job.new(name: "soak", cadence: "weekly", script: "/p/.fun-ci/weekly/soak.sh")

  def setup = setup_test_db
  def teardown = teardown_test_db

  def test_should_record_failed_a_job_whose_lock_nobody_holds
    runs = FunCi::Persistence::JobRuns.new(@db, "/p")
    runs.claim(SOAK, commit: { sha: "a" * 40, branch: "main" }, lock_file: File.join(@dir, "gone.lock"), now: Time.now)
    FunCi::Agent::LivePipeline.new(@dir).watch(@db)

    assert_equal "failed", runs.latest("soak")[:status]
  end
end
