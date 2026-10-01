# frozen_string_literal: true

require "time"
require_relative "../persistence/pipeline_run"
require_relative "../persistence/stage_job"
require_relative "../persistence/active_runs"
require_relative "../pipeline/run_canceller"
require_relative "streak_counter"
require_relative "trunk_marks"
require_relative "cancelled_folding"
require_relative "row_order"
require_relative "paging"
require_relative "job_rows"
require_relative "../persistence/active_jobs"

module FunCi
  module Console
    class BoardData
      # How many of a branch's runs are read to fold its cancelled ones and
      # find its standing against the trunk.
      BRANCH_WINDOW = 100

      # `clock` answers the time now, which decides which jobs are due.
      def initialize(db, page_size: 15, run_canceller: Pipeline::RunCanceller.new, clock: -> { Time.now })
        @db = db
        @paging = Paging.new(page_size)
        @run_canceller = run_canceller
        @clock = clock
      end

      def load_more = @paging.load_more

      # Pages by `page_size` from now on, loading at least one such page.
      def resize(page_size) = @paging.resize(page_size)

      # Whether there are branches beyond those `runs` loads.
      def more? = Persistence::PipelineRun.branch_heads(@db, limit: @paging.limit + 1).size > @paging.limit

      # Records failed each slow suite whose process died (acceptance-tests.md, AT-8.3).
      def record_dead_slow_suites = @run_canceller.record_dead(@db)

      # The job section's rows (JobRows): the jobs of the projects among `runs`.
      def jobs(runs)
        JobRows.new(@db).of(runs.map { |run| run[:project_path] }.uniq.compact, now: @clock.call)
      end

      # Records failed each job whose process died (acceptance-tests.md, AT-13.6).
      def record_dead_jobs = @run_canceller.record_dead_jobs(@db)

      # Stops a daily or weekly job's processes, then records it cancelled,
      # unless it has finished meanwhile.
      def cancel_job(id)
        Persistence::ActiveJobs.with_id(@db, id).each do |job|
          @run_canceller.stop(job)
          Persistence::ActiveJobs.cancelled(@db, id)
        end
      end

      # One row per branch, its newest run, for the branches that most need you
      # and then those run most recently, in RowOrder: a run of cancelled
      # runs folded into one, with its stages and the branch's standing against the trunk.
      def runs
        RowOrder.of(Persistence::PipelineRun.branch_heads(@db, limit: @paging.limit).map { |head| branch_row(head) })
      end

      # The projects among `runs` whose trunk is stale.
      def stale_trunks(runs, now:) = TrunkMarks.new(@db).stale(runs, now: now)

      def streak
        pipeline_runs = Persistence::PipelineRun.recent(@db, limit: @paging.limit)
        StreakCounter.count(pipeline_runs)
      end

      # Stops the run's processes, then records it cancelled. A run that has
      # finished meanwhile is left as it is.
      def cancel_run(run_id)
        Persistence::ActiveRuns.with_id(@db, run_id).each { |run| @run_canceller.cancel(@db, run) }
      end

      private

      def branch_row(head)
        branch_runs = Persistence::PipelineRun.of_branch(@db, head[:project_path], head[:branch], limit: BRANCH_WINDOW)
        row = CancelledFolding.fold(branch_runs).first
        enrich_with_stages(row.merge(trunk: TrunkMarks.new(@db).mark(branch_runs).first[:trunk]))
      end

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
