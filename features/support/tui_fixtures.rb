# frozen_string_literal: true

require "time"

# Writes pipeline runs and stage jobs into the test database.
class TuiFixtures
  RUN = FunCi::Persistence::PipelineRun
  JOB = FunCi::Persistence::StageJob
  RUN_FINAL_STATUSES = %w[completed failed timed_out cancelled].freeze
  STAGE_FINAL_STATUSES = %w[completed failed timed_out].freeze
  PASSED_DURATIONS = { build_time: 0.3, fast_time: 1.8, slow_time: 47 }.freeze

  def initialize(db)
    @db = db
    @now = Time.now
    @current_run_id = nil
  end

  def create_pipeline_run(commit:, branch:, status: "completed", minutes_ago: 0)
    @now = Time.now
    @current_run_id = RUN.create(@db, commit_hash: commit, branch: branch)
    advance_run(status)
    backdate_run(minutes_ago) if minutes_ago.positive?
    @current_run_id
  end

  def add_stage(stage:, status: "completed", duration: nil)
    job_id = JOB.create(@db, pipeline_run_id: @current_run_id, stage: stage)
    advance_job(job_id, status)
    record_timing(job_id, status, duration) if duration
    job_id
  end

  def create_full_passed_run(commit:, branch:, minutes_ago: 0, **durations)
    raise ArgumentError, "unknown durations: #{durations.keys}" unless (durations.keys - PASSED_DURATIONS.keys).empty?

    durations = PASSED_DURATIONS.merge(durations)
    create_pipeline_run(commit: commit, branch: branch, status: "completed", minutes_ago: minutes_ago)
    %w[build fast slow].map { |stage| add_stage(stage: stage, duration: durations[:"#{stage}_time"]) }.last
  end

  def complete_running_pipeline
    run_id = @db.get_first_value("SELECT id FROM pipeline_runs WHERE status = 'running' ORDER BY id DESC LIMIT 1")
    return unless run_id

    RUN.update_status(@db, run_id, "completed")
    stage_ids(run_id, "running").each { |id| JOB.update_status(@db, id, "completed") }
    stage_ids(run_id, "scheduled").each { |id| advance_job(id, "completed") }
  end

  private

  def advance_run(status)
    return if status == "scheduled"

    RUN.update_status(@db, @current_run_id, "running")
    RUN.update_status(@db, @current_run_id, status) if RUN_FINAL_STATUSES.include?(status)
  end

  def backdate_run(minutes_ago)
    past_time = (@now - (minutes_ago * 60)).utc.iso8601
    @db.execute("UPDATE pipeline_runs SET updated_at = ? WHERE id = ?", [past_time, @current_run_id])
  end

  def advance_job(job_id, status)
    return if status == "scheduled"

    JOB.update_status(@db, job_id, "running")
    JOB.update_status(@db, job_id, status) if STAGE_FINAL_STATUSES.include?(status)
  end

  def record_timing(job_id, status, duration)
    started = (@now - duration).utc.iso8601(3)
    if STAGE_FINAL_STATUSES.include?(status)
      @db.execute("UPDATE stage_jobs SET started_at = ?, completed_at = ? WHERE id = ?",
                  [started, @now.utc.iso8601(3), job_id])
    elsif status == "running"
      @db.execute("UPDATE stage_jobs SET started_at = ? WHERE id = ?", [started, job_id])
    end
  end

  def stage_ids(run_id, status)
    @db.execute("SELECT id FROM stage_jobs WHERE pipeline_run_id = ? AND status = ?", [run_id, status]).map(&:first)
  end
end
