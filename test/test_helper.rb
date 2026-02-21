# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/testing/parallelization"
require "active_support/testing/parallelize_executor"
require "concurrent/utility/processor_counter"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

Minitest.parallel_executor = ActiveSupport::Testing::ParallelizeExecutor.new(
  size: Concurrent.processor_count,
  with: :processes,
  threshold: 0
)

FakeStatus = Data.define(:success?, :exitstatus) unless defined?(FakeStatus)

class FakeRecorder
  attr_reader :calls

  def initialize
    @calls = []
    @next_job_id = 0
  end

  def create_run(commit_hash:, branch:) = @calls << [:create_run, commit_hash, branch]

  def start_stage(stage)
    @calls << [:start_stage, stage]
    @next_job_id += 1
  end
  def end_stage(job_id, status) = @calls << [:end_stage, job_id, status]
  def complete_run = @calls << [:complete_run]
  def fail_run = @calls << [:fail_run]
  def db = nil
  def db_path = nil
  def pipeline_run_id = nil
end

module FunCiTestProject
  def make_project_with_scripts(dir)
    fun_ci_dir = File.join(dir, ".fun-ci")
    Dir.mkdir(fun_ci_dir)
    %w[lint.sh build.sh fast.sh slow.sh].each do |script|
      path = File.join(fun_ci_dir, script)
      File.write(path, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, path)
    end
  end
end

module DatabaseTestSetup
  def setup_test_db
    @dir = Dir.mktmpdir
    db_path = File.join(@dir, "test.sqlite3")
    @db = FunCi::Database.connection(db_path)
    FunCi::Database.migrate!(@db)
  end

  def teardown_test_db
    @db.close
    FileUtils.remove_entry @dir
  end
end

module PipelineTestHelpers
  def create_completed_run(commit, branch)
    run_id = FunCi::PipelineRun.create(@db, commit_hash: commit, branch: branch)
    FunCi::PipelineRun.update_status(@db, run_id, "running")
    FunCi::PipelineRun.update_status(@db, run_id, "completed")
    %w[lint build fast slow].each do |stage|
      job_id = FunCi::StageJob.create(@db, pipeline_run_id: run_id, stage: stage)
      FunCi::StageJob.update_status(@db, job_id, "running")
      FunCi::StageJob.update_status(@db, job_id, "completed")
    end
    run_id
  end

  def create_failed_run(commit, branch)
    run_id = FunCi::PipelineRun.create(@db, commit_hash: commit, branch: branch)
    FunCi::PipelineRun.update_status(@db, run_id, "running")
    FunCi::PipelineRun.update_status(@db, run_id, "failed")
    lint_id = FunCi::StageJob.create(@db, pipeline_run_id: run_id, stage: "lint")
    FunCi::StageJob.update_status(@db, lint_id, "running")
    FunCi::StageJob.update_status(@db, lint_id, "completed")
    build_id = FunCi::StageJob.create(@db, pipeline_run_id: run_id, stage: "build")
    FunCi::StageJob.update_status(@db, build_id, "running")
    FunCi::StageJob.update_status(@db, build_id, "completed")
    fast_id = FunCi::StageJob.create(@db, pipeline_run_id: run_id, stage: "fast")
    FunCi::StageJob.update_status(@db, fast_id, "running")
    FunCi::StageJob.update_status(@db, fast_id, "failed")
    FunCi::StageJob.create(@db, pipeline_run_id: run_id, stage: "slow")
    run_id
  end
end
