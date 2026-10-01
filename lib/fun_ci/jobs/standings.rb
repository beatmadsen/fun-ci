# frozen_string_literal: true

require_relative "folders"
require_relative "due"
require_relative "state"
require_relative "../persistence/job_runs"

module FunCi
  module Jobs
    # Where a job stands: its project, the job, its latest run as job_runs
    # keeps it (nil while it never ran), and Due, which says whether the
    # next commit starts it and when it is due again.
    Standing = Data.define(:project, :job, :run, :due)

    class Standing
      def name = job.name
      def cadence = job.cadence
      def state = State.of(run)
      def needs_you? = State.needs_you?(state)
      def due_now? = due.now?
      def due_at = due.at
    end

    # Where each of a project's jobs stands at `now`, read once for the
    # console, the agent commands and the trigger.
    class Standings
      def initialize(db, project, now:)
        @db = db
        @project = project
        @now = now
      end

      # By name.
      def all
        runs = Persistence::JobRuns.new(@db, @project)
        Folders.new(@project).jobs.map { |job| standing(job, runs.latest(job.name)) }
      end

      private

      def standing(job, run)
        Standing.new(project: @project, job: job, run: run, due: Due.new(run, job.period, now: @now))
      end
    end
  end
end
