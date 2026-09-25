# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trigger_test_kit"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_recorder"

class TestTriggerPersistence < Minitest::Test
  include FunCiTestProject
  include DatabaseTestSetup
  include TriggerTestKit

  def setup = setup_test_db
  def teardown = teardown_test_db

  def test_should_create_pipeline_run_when_recorder_provided
    run_pipeline

    assert_equal %w[abc1234 main], stored_run.values_at(:commit_hash, :branch)
  end

  def test_should_create_stage_jobs_for_each_stage_when_recorder_provided
    run_pipeline
    stages = @db.execute("SELECT stage FROM stage_jobs WHERE pipeline_run_id = ?", [stored_run[:id]]).flatten

    assert_equal %w[build fast lint slow], stages.sort
  end

  def test_should_update_pipeline_run_to_completed_when_all_stages_pass
    run_pipeline

    assert_equal "completed", stored_run[:status]
  end

  def test_should_update_pipeline_run_to_failed_when_build_fails
    run_pipeline("build.sh" => failing("build error"))

    assert_equal "failed", stored_run[:status]
  end

  private

  def run_pipeline(answers = {})
    in_project do |dir|
      build_trigger(dir, command_runner: scripted_runner(answers), recorder: FunCi::Persistence::DbRecorder.new(@db),
                         background_launcher: method(:sync_launcher)).run
    end
  end

  def stored_run = FunCi::Persistence::PipelineRun.find_by_commit(@db, "abc1234").first

  def sync_launcher(db_path:, pipeline_run_id:, job_id:, executor:)
    recorder = FunCi::Persistence::DbRecorder.for_background(db_path, pipeline_run_id)
    FunCi::Pipeline::BackgroundWrapper.new(recorder: recorder, job_id: job_id, executor: executor).run
    recorder.close
  end
end
