# frozen_string_literal: true

require "time"
require_relative "../persistence/pipeline_run"
require_relative "../persistence/stage_job"
require_relative "../persistence/active_runs"
require_relative "../pipeline/run_canceller"
require_relative "streak_counter"

module FunCi
  module Console
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

      # Pages by `page_size` from now on, loading at least one such page.
      def resize(page_size)
        @page_size = page_size
        @limit = [@limit, page_size].max
      end

      # Whether the store holds runs beyond those `runs` loads.
      def more?
        Persistence::PipelineRun.recent(@db, limit: @limit + 1).size > @limit
      end

      # Records failed each slow suite whose process died (acceptance-tests.md, AT-8.3).
      def record_dead_slow_suites = @run_canceller.record_dead(@db)

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
        Persistence::ActiveRuns.with_id(@db, run_id).each { |run| @run_canceller.cancel(@db, run) }
      end

      private

      def enrich_with_stages(run)
        run.merge(stages: Persistence::StageJob.for_run(@db, run[:id]).map { |job| stage(job) })
      end

      def stage(job)
        { stage: job[:stage], status: job[:status], duration: Persistence::StageJob.elapsed_duration(job),
          started_at: job[:started_at], finished_order: job[:finished_order] }
      end
    end
  end
end
