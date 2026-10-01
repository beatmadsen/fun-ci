# frozen_string_literal: true

require_relative "job_order"
require_relative "../jobs/folders"
require_relative "../jobs/due"
require_relative "../persistence/job_runs"

module FunCi
  module Console
    # The job section's rows (design.md, The console): each daily and
    # weekly job of the board's projects, as its latest run left it, or due
    # when it never ran or that run was cancelled, with when it is due again.
    # Each is { project:, name:, cadence:, status:, run:, due_at: }, in JobOrder.
    class JobRows
      def initialize(db)
        @db = db
      end

      def of(projects, now:)
        rows = projects.flat_map { |project| project_rows(project, now) }
        JobOrder.of(rows, projects: projects)
      end

      private

      def project_rows(project, now)
        runs = Persistence::JobRuns.new(@db, project)
        Jobs::Folders.new(project).jobs.map { |job| row(project, job, runs.latest(job.name), now) }
      end

      def row(project, job, run, now)
        { project: project, name: job.name, cadence: job.cadence, status: status(run), run: run,
          due_at: Jobs::Due.new(run, job.period, now: now).at }
      end

      def status(run) = run.nil? || run[:status] == "cancelled" ? "due" : run[:status]
    end
  end
end
