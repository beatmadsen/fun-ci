# frozen_string_literal: true

require_relative "folders"
require_relative "due"
require_relative "../persistence/job_runs"

module FunCi
  module Jobs
    # The project's jobs that are due at `now`, read from the database without
    # taking any lock: who starts a job is decided again, under its lock, by
    # the process that runs it.
    class DueJobs
      def initialize(project, db, now:)
        @project = project
        @db = db
        @now = now
      end

      def list
        runs = Persistence::JobRuns.new(@db, @project)
        Folders.new(@project).jobs.select { |job| Due.new(runs.latest(job.name), job.period, now: @now).now? }
      end
    end
  end
end
