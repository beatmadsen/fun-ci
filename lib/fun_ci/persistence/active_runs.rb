# frozen_string_literal: true

require "time"
require_relative "pipeline_run"
require_relative "stage_job"

module FunCi
  module Persistence
    # A run that has not finished: the processes running it (the trigger and
    # the forked slow suite), the process group of each stage still going, and
    # the lock of the worktree slot it holds (nil while it waits for one).
    ActiveRun = Data.define(:id, :commit_hash, :processes, :stage_groups, :slot_lock)

    # Runs waiting for a slot or running, and recording one as cancelled.
    module ActiveRuns
      ACTIVE = "status IN ('scheduled', 'running')"

      def self.on_branch(db, branch) = where(db, "branch = ?", branch)

      # The run with this id, when it has not finished; none otherwise.
      def self.with_id(db, id) = where(db, "id = ?", id)

      # [job id, run id, pid] for each slow stage still running, pid being the
      # forked process that runs it.
      def self.slow_suites(db)
        db.execute("SELECT stage_jobs.id, pipeline_runs.id, pipeline_runs.pid FROM stage_jobs " \
                   "JOIN pipeline_runs ON pipeline_runs.id = stage_jobs.pipeline_run_id " \
                   "WHERE stage_jobs.stage = 'slow' AND stage_jobs.status = 'running' " \
                   "AND pipeline_runs.pid IS NOT NULL")
      end

      # Records the slow stage failed, unless its result was recorded meanwhile.
      def self.slow_suite_died(db, job_id)
        db.execute("UPDATE stage_jobs SET status = 'failed', completed_at = ? WHERE id = ? AND status = 'running'",
                   [Time.now.utc.iso8601, job_id])
      end

      def self.cancelled(db, run)
        db.execute("UPDATE stage_jobs SET status = 'cancelled', completed_at = ? " \
                   "WHERE pipeline_run_id = ? AND #{ACTIVE}", [Time.now.utc.iso8601, run.id])
        PipelineRun.update_status(db, run.id, "cancelled")
      end

      def self.where(db, clause, value)
        db.execute("SELECT id, commit_hash, trigger_pid, pid, slot_lock FROM pipeline_runs " \
                   "WHERE #{clause} AND #{ACTIVE} ORDER BY id", [value]).map { |row| active_run(db, row) }
      end
      private_class_method :where

      def self.active_run(db, (id, commit_hash, trigger_pid, pid, slot_lock))
        groups = db.execute("SELECT pid FROM stage_jobs WHERE pipeline_run_id = ? AND #{ACTIVE} AND pid IS NOT NULL",
                            [id]).flatten
        ActiveRun.new(id: id, commit_hash: commit_hash, processes: [trigger_pid, pid].compact, stage_groups: groups,
                      slot_lock: slot_lock)
      end
      private_class_method :active_run
    end
  end
end
