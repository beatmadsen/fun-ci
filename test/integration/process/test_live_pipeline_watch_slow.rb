# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/live_pipeline"
require "fun_ci/persistence/database"

# What wait and events --follow look for on each poll, besides dead jobs: a
# slow suite whose forked process died without recording its result
# (acceptance-tests.md, AT-8.3).
class TestLivePipelineWatchSlow < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup = setup_test_db
  def teardown = teardown_test_db

  def test_should_record_failed_a_slow_suite_whose_process_died
    run_id = create_pipeline_run("abc1234", "main", "running")
    slow = create_stage_job(run_id, "slow", "running")
    FunCi::Persistence::PipelineRun.store_pid(@db, run_id, a_dead_pid)
    FunCi::Agent::LivePipeline.new(@dir).watch(@db)

    assert_equal "failed", FunCi::Persistence::StageJob.find(@db, slow)[:status]
  end

  private

  # A process that has ended and been waited for, so nothing has its pid.
  def a_dead_pid
    pid = Process.spawn("true")
    Process.waitpid(pid)
    pid
  end
end
