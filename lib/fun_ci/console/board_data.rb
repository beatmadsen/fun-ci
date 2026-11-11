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
require_relative "../persistence/branch_visibility"

module FunCi
  module Console
    class BoardData
      # How many of a branch's runs are read to fold its cancelled ones and
      # find its standing against the trunk.
      BRANCH_WINDOW = 100
      # How many branches the board holds at most: those whose newest run
      # changed most recently, so old failures leave it in time.
      RECENT_BRANCHES = 20

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
      def more? = heads(@paging.limit + 1).size > @paging.limit

      # Records failed each slow suite whose process died (acceptance-tests.md, AT-8.3).
      def record_dead_slow_suites = @run_canceller.record_dead(@db)

      # The job section's rows (JobRows): the jobs of the projects among
      # `runs`, those the user hid among them, marked.
      def jobs(runs)
        JobRows.new(@db).of(runs.map { |run| run[:project_path] }.uniq.compact, now: @clock.call)
      end

      # Keeps the job of `row` (a JobRow) out of view from now: `snoozed`, until it runs again, or `ignored`.
      def hide_job(row, kind)
        Persistence::JobVisibility.new(@db).hide(row.project, row.name, kind, at: @clock.call)
      end

      def show_job(row) = Persistence::JobVisibility.new(@db).show(row.project, row.name)

      # Keeps the branch of the run `row` out of view from now: `snoozed`, until its next run, or `ignored`.
      def hide_run(row, kind)
        Persistence::BranchVisibility.new(@db).hide(row[:project_path], row[:branch], kind, at: @clock.call)
      end

      def show_run(row) = Persistence::BranchVisibility.new(@db).show(row[:project_path], row[:branch])

      # Records failed each job whose process died (acceptance-tests.md, AT-13.6).
      def record_dead_jobs = @run_canceller.record_dead_jobs(@db)

      # Stops a daily or weekly job's processes, then records it cancelled,
      # unless it has finished meanwhile.
      def cancel_job(id) = @run_canceller.cancel_job(@db, id)

      # One row per branch, its newest run, for the branches that most need you
      # and then those run most recently, in RowOrder: a run of cancelled
      # runs folded into one, with its stages, the branch's standing against
      # the trunk, and how the user hid the branch (`hidden`, nil while in view).
      # A hidden branch leaves its place to the next one: as many more are read, and the page keeps as many in view.
      def runs
        hidden = Persistence::BranchVisibility.new(@db).hidden
        rows = heads(@paging.limit + hidden.size, more_among: hidden.size).map { |head| branch_row(head, hidden) }
        RowOrder.of(in_view_within_the_page(rows))
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

      def heads(limit, more_among: 0)
        Persistence::PipelineRun.branch_heads(@db, limit: limit, among: RECENT_BRANCHES + more_among)
      end

      # The hidden branches' rows, and as many of the others as a page holds, the first.
      def in_view_within_the_page(rows)
        in_view = rows.reject { |row| row[:hidden] }.first(@paging.limit)
        rows.select { |row| row[:hidden] || in_view.include?(row) }
      end

      def branch_row(head, hidden)
        branch_runs = Persistence::PipelineRun.leading_to(@db, head, limit: BRANCH_WINDOW)
        row = CancelledFolding.fold(branch_runs).first
        trunk = TrunkMarks.new(@db).mark(branch_runs).first[:trunk]
        enrich_with_stages(row.merge(trunk: trunk, hidden: hidden[[head[:project_path], head[:branch]]]))
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
