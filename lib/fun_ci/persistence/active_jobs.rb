# frozen_string_literal: true

require "time"
require_relative "active_runs"

module FunCi
  module Persistence
    # Daily and weekly jobs' runs still running, of every project, as the
    # console sees them: to cancel one, and to notice one whose process died.
    module ActiveJobs
      # The job run with this id as an ActiveRun, when it still runs; none otherwise.
      def self.with_id(db, id)
        db.execute("SELECT id, commit_hash, pid, group_pid, lock_file FROM job_runs " \
                   "WHERE id = ? AND status = 'running'", [id]).map do |(run_id, sha, pid, group_pid, lock_file)|
          ActiveRun.new(id: run_id, commit_hash: sha, processes: [pid].compact, stage_groups: [group_pid].compact,
                        slot_lock: lock_file)
        end
      end

      # [id, lock file] of each job run still running.
      def self.running(db) = db.execute("SELECT id, lock_file FROM job_runs WHERE status = 'running'")

      def self.cancelled(db, id) = ended(db, id, "cancelled")

      # A run whose process is gone without recording how it ended.
      def self.died(db, id) = ended(db, id, "failed")

      def self.ended(db, id, status)
        db.execute("UPDATE job_runs SET status = ?, completed_at = ? WHERE id = ? AND status = 'running'",
                   [status, Time.now.utc.iso8601(3), id])
      end
      private_class_method :ended
    end
  end
end
