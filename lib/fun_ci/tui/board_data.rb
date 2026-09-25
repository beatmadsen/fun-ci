# frozen_string_literal: true

require "time"
require_relative "../persistence/pipeline_run"
require_relative "../persistence/stage_job"
require_relative "../persistence/active_runs"
require_relative "../pipeline/run_canceller"
require_relative "streak_counter"

module FunCi
  module Tui
    class BoardData
      def initialize(db, limit: 15, page_size: nil, run_canceller: Pipeline::RunCanceller.new)
        @db = db
        @page_size = page_size || limit
        @limit = @page_size
        @run_canceller = run_canceller
      end

      def load_more
        @limit += @page_size
      end

      def runs
        pipeline_runs = Persistence::PipelineRun.recent(@db, limit: @limit)
        pipeline_runs.map { |run| enrich_with_stages(run) }
      end

      def streak
        pipeline_runs = Persistence::PipelineRun.recent(@db, limit: @limit)
        StreakCounter.count(pipeline_runs)
      end

      # Stops the run's processes, then records it cancelled. A run that has
      # finished meanwhile is left as it is.
      def cancel_run(run_id)
        Persistence::ActiveRuns.with_id(@db, run_id).each do |run|
          @run_canceller.stop(run)
          Persistence::ActiveRuns.cancelled(@db, run)
        end
      end

      private

      def enrich_with_stages(run)
        rows = @db.execute(
          "SELECT id, pipeline_run_id, stage, status, started_at, completed_at FROM stage_jobs WHERE pipeline_run_id = ? ORDER BY id",
          [run[:id]]
        )

        stages = rows.map do |row|
          job = { id: row[0], pipeline_run_id: row[1], stage: row[2], status: row[3], started_at: row[4], completed_at: row[5] }
          duration = Persistence::StageJob.elapsed_duration(job)
          { stage: job[:stage], status: job[:status], duration: duration, started_at: job[:started_at] }
        end

        run.merge(stages: stages)
      end
    end
  end
end
