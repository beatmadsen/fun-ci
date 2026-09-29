# frozen_string_literal: true

require "time"
require_relative "../persistence/pipeline_run"
require_relative "../persistence/stage_job"
require_relative "../persistence/active_runs"
require_relative "../pipeline/run_canceller"
require_relative "streak_counter"
require_relative "trunk_marks"
require_relative "cancelled_folding"

module FunCi
  module Console
    class BoardData
      # How many pages of runs are read, so a page is full once cancelled runs are folded.
      WINDOW_PAGES = 4

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

      # Whether there are rows beyond those `runs` loads, folded or still unread.
      def more?
        window = Persistence::PipelineRun.recent(@db, limit: window_size + 1)
        window.size > window_size || CancelledFolding.fold(window).size > @limit
      end

      # Records failed each slow suite whose process died (acceptance-tests.md, AT-8.3).
      def record_dead_slow_suites = @run_canceller.record_dead(@db)

      # Newest first, a branch's consecutive cancelled runs folded into one, each
      # with its stages and, a branch's newest, the branch's standing against the trunk.
      def runs
        pipeline_runs = CancelledFolding.fold(Persistence::PipelineRun.recent(@db, limit: window_size)).first(@limit)
        TrunkMarks.new(@db).mark(pipeline_runs.map { |run| enrich_with_stages(run) })
      end

      # The projects among `runs` whose trunk is stale.
      def stale_trunks(runs, now:) = TrunkMarks.new(@db).stale(runs, now: now)

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

      def window_size = @limit * WINDOW_PAGES

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
