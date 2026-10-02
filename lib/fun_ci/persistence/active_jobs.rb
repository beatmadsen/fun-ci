# frozen_string_literal: true

require "time"
require_relative "active_runs"
require "json"
require_relative "../evidence/document"

module FunCi
  module Persistence
    # Daily and weekly jobs' runs still running, of every project, as the
    # console sees them: to cancel one, and to notice one whose process died.
    module ActiveJobs
      # A run is still going while it runs, or waits its turn to (Jobs::Schedule).
      ACTIVE = "status IN ('running', 'scheduled')"

      # The job run with this id as an ActiveRun, when it still runs; none otherwise.
      def self.with_id(db, id)
        db.execute("SELECT id, commit_hash, pid, group_pid, lock_file FROM job_runs " \
                   "WHERE id = ? AND #{ACTIVE}", [id]).map do |(run_id, sha, pid, group_pid, lock_file)|
          ActiveRun.new(id: run_id, commit_hash: sha, processes: [pid].compact, stage_groups: [group_pid].compact,
                        slot_lock: lock_file)
        end
      end

      # [id, lock file] of each job run still running.
      def self.running(db) = db.execute("SELECT id, lock_file FROM job_runs WHERE #{ACTIVE}")

      # What a run whose process died keeps: that it has no result, and why
      # that may be. It keeps no end, since when it was found dead says
      # nothing of how long it ran.
      DIED_FACT = { name: "ended", extractor: "fun-ci",
                    value: "its process stopped before it said how the run ended (the machine slept or " \
                           "restarted, or something killed it), so this run has no result" }.freeze
      DIED = Evidence::Document.new(chosen: [], failures: [], excerpts: [], problems: [], facts: [DIED_FACT])

      def self.cancelled(db, id) = ended(db, id, "cancelled", ACTIVE)

      # A run whose process is gone without recording how it ended: failed,
      # with no end; one that was still waiting its turn never ran, so it is
      # cancelled, and the job is due at the next commit.
      def self.died(db, id)
        ended(db, id, "cancelled", "status = 'scheduled'")
        db.execute("UPDATE job_runs SET status = 'failed', evidence = ? WHERE id = ? AND status = 'running'",
                   [JSON.generate(DIED.to_h), id])
      end

      # The ids of a project's job's runs still running.
      def self.running_of(db, project, name)
        db.execute("SELECT id FROM job_runs WHERE project_path = ? AND job = ? AND #{ACTIVE}",
                   [project, name]).flatten
      end

      def self.ended(db, id, status, was)
        db.execute("UPDATE job_runs SET status = ?, completed_at = ? WHERE id = ? AND #{was}",
                   [status, Time.now.utc.iso8601(3), id])
      end
      private_class_method :ended
    end
  end
end
