# frozen_string_literal: true

require "time"
require_relative "standings"
require_relative "schedule"
require_relative "../pipeline/run_canceller"
require_relative "../setup/project_config"

module FunCi
  module Jobs
    # The project's jobs that are due at `now`, read from the database without
    # taking any lock: who starts a job is decided again, under its lock, by
    # the process that runs it. A job left running by a process that died is
    # recorded failed first, or it would never be due again, and no process
    # would start to find it dead.
    class DueJobs
      BEGUN = %w[running scheduled].freeze
      DAY = 86_400

      def initialize(project, db, now:)
        @project = project
        @db = db
        @now = now
      end

      def list = standings.select(&:due_now?).map(&:job)

      # [job, when its turn to start comes] for each due job (Schedule): a day
      # shared evenly among the project's jobs apart, or its `job_spacing`,
      # after its jobs still running or waiting to. Each is due again a
      # period after its own start, so the spread holds from day to day.
      def starts
        all = standings
        Schedule.new(spacing(all.size), begun(all), now: @now).starts(all.select(&:due_now?).map(&:job))
      end

      private

      def spacing(jobs) = Setup::ProjectConfig.new(@project).job_spacing || (DAY / [jobs, 1].max)

      # When each of the project's jobs still running or waiting to began, or is to.
      def begun(all) = all.select { |one| BEGUN.include?(one.state) }.map { |one| Time.parse(one.run[:started_at]) }

      def standings
        Pipeline::RunCanceller.new.record_dead_jobs(@db)
        Standings.new(@db, @project, now: @now).all
      end
    end
  end
end
