# frozen_string_literal: true

require "time"
require_relative "pipeline_run"
require_relative "stage_job"
require_relative "streak_counter"

module FunCi
  class BoardData
    def initialize(db, limit: 20, page_size: nil)
      @db = db
      @page_size = page_size || limit
      @limit = @page_size
    end

    def load_more
      @limit += @page_size
    end

    def runs
      pipeline_runs = PipelineRun.recent(@db, limit: @limit)
      pipeline_runs.map { |run| enrich_with_stages(run) }
    end

    def streak
      pipeline_runs = PipelineRun.recent(@db, limit: @limit)
      StreakCounter.count(pipeline_runs)
    end

    def cancel_run(run_id)
      PipelineRun.update_status(@db, run_id, "cancelled")
    end

    private

    def enrich_with_stages(run)
      rows = @db.execute(
        "SELECT id, pipeline_run_id, stage, status, started_at, completed_at FROM stage_jobs WHERE pipeline_run_id = ? ORDER BY id",
        [run[:id]]
      )

      stages = rows.map do |row|
        job = { id: row[0], pipeline_run_id: row[1], stage: row[2], status: row[3], started_at: row[4], completed_at: row[5] }
        duration = StageJob.elapsed_duration(job)
        { stage: job[:stage], status: job[:status], duration: duration, started_at: job[:started_at] }
      end

      run.merge(stages: stages)
    end
  end
end
