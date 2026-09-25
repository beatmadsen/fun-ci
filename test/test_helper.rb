# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/testing/parallelization"
require "active_support/testing/parallelize_executor"
require "concurrent/utility/processor_counter"

require_relative "support/sqlite_connection_guard"
require_relative "support/stray_stderr_guard"
require_relative "support/confinement_guard"
require_relative "support/spawn_guard"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
ConfinementGuard.install
StrayStderrGuard.install
SqliteConnectionGuard.install
SpawnGuard.install
# Minitest shells out to `diff -u` to show long strings that differ, which the
# spawn guard would turn into an error; plain Expected/Actual output instead.
Minitest::Assertions.diff = nil
Minitest::Test.prepend(ConfinementGuard::CheckAfterTest)

# Mutineer already forks a worker per mutant; forking again here would multiply
# processes until the machine runs out of memory, so a mutation run is serial.
unless ENV["MUTATION_TESTING"]
  Minitest.parallel_executor = ActiveSupport::Testing::ParallelizeExecutor.new(
    size: Concurrent.processor_count,
    with: :processes,
    threshold: 0
  )
end

FakeStatus = Data.define(:success?, :exitstatus) unless defined?(FakeStatus)

class FakeRecorder
  attr_reader :calls

  def initialize
    @calls = []
    @next_job_id = 0
  end

  def create_run(commit_hash:, branch:, project_path: nil) = @calls << [:create_run, commit_hash, branch, project_path]

  def start_stage(stage)
    @calls << [:start_stage, stage]
    @next_job_id += 1
  end

  def end_stage(job_id, status) = @calls << [:end_stage, job_id, status]
  def stage_process(job_id, pid) = @calls << [:stage_process, job_id, pid]
  def slot_taken(lock_file) = @calls << [:slot_taken, lock_file]
  def complete_run = @calls << [:complete_run]
  def fail_run = @calls << [:fail_run]
  def close = nil
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
    @db = FunCi::Persistence::Database.connection(db_path)
    FunCi::Persistence::Database.migrate!(@db)
  end

  def teardown_test_db
    @db.close
    FileUtils.remove_entry @dir
  end
end

module PipelineTestHelpers
  def create_completed_run(commit, branch)
    run_id = create_pipeline_run(commit, branch, "completed")
    %w[lint build fast slow].each { |stage| create_stage_job(run_id, stage, "running", "completed") }
    run_id
  end

  def create_failed_run(commit, branch)
    run_id = create_pipeline_run(commit, branch, "failed")
    create_stage_job(run_id, "lint", "running", "completed")
    create_stage_job(run_id, "build", "running", "completed")
    create_stage_job(run_id, "fast", "running", "failed")
    create_stage_job(run_id, "slow")
    run_id
  end

  def create_pipeline_run(commit, branch, final_status)
    run_id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: commit, branch: branch)
    FunCi::Persistence::PipelineRun.update_status(@db, run_id, "running")
    FunCi::Persistence::PipelineRun.update_status(@db, run_id, final_status)
    run_id
  end

  def create_stage_job(run_id, stage, *statuses)
    job_id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: run_id, stage: stage)
    statuses.each { |status| FunCi::Persistence::StageJob.update_status(@db, job_id, status) }
    job_id
  end
end

require_relative "support/animation_renderer_test_helpers"
