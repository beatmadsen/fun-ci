# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"

# A run's stages are numbered in the order they finished, as they are
# recorded, so the order holds however close together they finished.
class TestStageFinishOrder < Minitest::Test
  include DatabaseTestSetup

  JOB = FunCi::Persistence::StageJob

  def setup
    setup_test_db
    @run_id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "abc1234", branch: "main")
    @lint, @build = %w[lint build].map { |stage| JOB.create(@db, pipeline_run_id: @run_id, stage: stage) }
  end

  def teardown
    teardown_test_db
  end

  def test_should_number_the_stages_in_the_order_they_finished
    JOB.update_status(@db, @build, "completed")
    JOB.update_status(@db, @lint, "completed")

    assert_equal([2, 1], [@lint, @build].map { |id| JOB.find(@db, id)[:finished_order] })
  end

  def test_should_number_each_run_s_stages_from_one
    other_run = FunCi::Persistence::PipelineRun.create(@db, commit_hash: "def5678", branch: "main")
    other = JOB.create(@db, pipeline_run_id: other_run, stage: "lint")
    JOB.update_status(@db, @lint, "completed")

    JOB.update_status(@db, other, "failed")

    assert_equal 1, JOB.find(@db, other)[:finished_order]
  end

  def test_should_leave_a_stage_that_only_started_unnumbered
    JOB.update_status(@db, @lint, "running")

    assert_nil JOB.find(@db, @lint)[:finished_order]
  end
end
