# frozen_string_literal: true

require "time"
require_relative "pipeline_run"
require_relative "stage_job"
require_relative "died"
require_relative "arrival"

module FunCi
  module Persistence
    # A run that has not finished: the processes running it (the trigger and
    # the forked slow suite), the process group of each stage still going, and
    # the lock of the worktree slot it holds (nil while it waits for one).
    ActiveRun = Data.define(:id, :commit_hash, :processes, :stage_groups, :slot_lock)

    # A branch of one project. Every project records its runs in the same
    # database, and two projects can each have a main.
    Branch = Data.define(:project, :name)

    # Runs waiting for a slot or running, and recording one as cancelled.
    module ActiveRuns
      ACTIVE = "status IN ('scheduled', 'running')"

      # Records cancelled, and returns, the runs on the branch a new commit's
      # run cancels: those of commits that arrived before it (acceptance-tests.md,
      # AT-9.20), except one an agent has waited on since `waited_before` (an
      # ISO 8601 UTC time; AT-9.12) and one whose slow suite is running (AT-9.19).
      # Picked and recorded in one statement, before their processes are
      # stopped, so a slow suite whose turn comes meanwhile never starts
      # (StageJob.started_in_turn?).
      def self.cancel_stale(db, branch, new_commit:, waited_before:)
        values = [Time.now.utc.iso8601, branch.project, branch.name, branch.project, branch.name, new_commit,
                  waited_before]
        rows = db.execute("UPDATE pipeline_runs SET status = 'cancelled', updated_at = ? WHERE #{STALE} " \
                          "RETURNING #{RUN_COLUMNS}", values)
        rows.sort_by(&:first).map { |row| active_run(db, row) }
      end

      # A commit arrives on its branch with its first run; a commit with none yet arrives last.
      ARRIVED_BEFORE = "#{Arrival::FIRST_RUN} < COALESCE((SELECT MIN(id) FROM pipeline_runs " \
                       "WHERE project_path = ? AND branch = ? AND commit_hash = ?), #{Arrival::NOT_YET})".freeze
      SLOW_RUNNING = "SELECT 1 FROM stage_jobs WHERE pipeline_run_id = pipeline_runs.id " \
                     "AND stage = 'slow' AND status = 'running'"
      STALE = "project_path = ? AND branch = ? AND #{ARRIVED_BEFORE} AND (waited_at IS NULL OR waited_at < ?) " \
              "AND NOT EXISTS (#{SLOW_RUNNING}) AND #{ACTIVE}".freeze
      RUN_COLUMNS = "id, commit_hash, trigger_pid, pid, slot_lock, fetch_pgid"

      # The run with this id, when it has not finished; none otherwise.
      def self.with_id(db, id) = where(db, "id = ?", id)

      # [job id, run id, pid] for each slow stage still running or waiting its
      # turn (AT-9.19), pid being the forked process that runs it.
      def self.slow_suites(db)
        db.execute("SELECT stage_jobs.id, pipeline_runs.id, pipeline_runs.pid FROM stage_jobs " \
                   "JOIN pipeline_runs ON pipeline_runs.id = stage_jobs.pipeline_run_id " \
                   "WHERE stage_jobs.stage = 'slow' AND stage_jobs.#{ACTIVE} " \
                   "AND pipeline_runs.pid IS NOT NULL")
      end

      # Records the slow stage failed, numbered after every other stage of its
      # run that finished, and that its process died, unless its result was
      # recorded meanwhile.
      def self.slow_suite_died(db, job_id)
        db.execute("UPDATE stage_jobs SET status = 'failed', completed_at = ?, " \
                   "finished_order = #{StageJob::NEXT_IN_RUN}, evidence = ? WHERE id = ? AND #{ACTIVE}",
                   [Time.now.utc.iso8601(3), Died.evidence("stage"), job_id])
      end

      def self.cancelled(db, run)
        db.execute("UPDATE stage_jobs SET status = 'cancelled', completed_at = ? " \
                   "WHERE pipeline_run_id = ? AND #{ACTIVE}", [Time.now.utc.iso8601(3), run.id])
        PipelineRun.update_status(db, run.id, "cancelled")
      end

      # The process groups of the run's stages still going, and its trunk
      # fetch's, whatever the run's own status says.
      def self.groups(db, id)
        fetch = db.execute("SELECT fetch_pgid FROM pipeline_runs WHERE id = ?", [id]).flatten.compact
        [*stage_groups(db, id), *fetch]
      end

      def self.where(db, clause, *values)
        db.execute("SELECT #{RUN_COLUMNS} FROM pipeline_runs " \
                   "WHERE #{clause} AND #{ACTIVE} ORDER BY id", values).map { |row| active_run(db, row) }
      end
      private_class_method :where

      # The groups are each running stage's, and the trunk fetch's (architecture.md, Checking against the trunk).
      def self.active_run(db, (id, commit_hash, trigger_pid, pid, slot_lock, fetch_pgid))
        ActiveRun.new(id: id, commit_hash: commit_hash, processes: [trigger_pid, pid].compact,
                      stage_groups: [*stage_groups(db, id), *fetch_pgid], slot_lock: slot_lock)
      end
      private_class_method :active_run

      def self.stage_groups(db, id)
        db.execute("SELECT pid FROM stage_jobs WHERE pipeline_run_id = ? AND #{ACTIVE} AND pid IS NOT NULL",
                   [id]).flatten
      end
      private_class_method :stage_groups
    end
  end
end
