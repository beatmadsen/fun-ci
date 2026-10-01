# frozen_string_literal: true

require_relative "folders"
require_relative "due"
require_relative "../persistence/job_runs"
require_relative "../pipeline/run_canceller"

module FunCi
  module Jobs
    # The project's jobs that are due at `now`, read from the database without
    # taking any lock: who starts a job is decided again, under its lock, by
    # the process that runs it. A job left running by a process that died is
    # recorded failed first, or it would never be due again, and no process
    # would start to find it dead.
    class DueJobs
      def initialize(project, db, now:)
        @project = project
        @db = db
        @now = now
      end

      def list
        Pipeline::RunCanceller.new.record_dead_jobs(@db)
        runs = Persistence::JobRuns.new(@db, @project)
        Folders.new(@project).jobs.select { |job| Due.new(runs.latest(job.name), job.period, now: @now).now? }
      end
    end
  end
end
