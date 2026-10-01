# frozen_string_literal: true

require "time"

module FunCi
  module Persistence
    module PipelineRun
      COLUMNS = %i[id commit_hash branch status pid project_path created_at updated_at trunk_started_at
                   trigger_pid].freeze
      SELECT = "SELECT #{COLUMNS.join(", ")} FROM pipeline_runs".freeze

      def self.create(db, commit_hash:, branch:, project_path: nil)
        now = Time.now.utc.iso8601
        db.execute(
          "INSERT INTO pipeline_runs (commit_hash, branch, project_path, status, created_at, updated_at) " \
          "VALUES (?, ?, ?, 'scheduled', ?, ?)",
          [commit_hash, branch, project_path, now, now]
        )
        db.last_insert_row_id
      end

      def self.find(db, id)
        query(db, "WHERE id = ?", id).first
      end

      def self.find_by_branch(db, branch)
        query(db, "WHERE branch = ? ORDER BY id DESC", branch)
      end

      def self.find_by_commit(db, commit_hash)
        query(db, "WHERE commit_hash = ? ORDER BY id DESC", commit_hash)
      end

      # The forked slow suite's process.
      def self.store_pid(db, id, pid)
        db.execute("UPDATE pipeline_runs SET pid = ? WHERE id = ?", [pid, id])
      end

      # The lock file of the worktree slot the run holds.
      def self.store_slot_lock(db, id, path)
        db.execute("UPDATE pipeline_runs SET slot_lock = ? WHERE id = ?", [path, id])
      end

      # The process running the pipeline itself.
      def self.store_trigger_pid(db, id, pid)
        db.execute("UPDATE pipeline_runs SET trigger_pid = ? WHERE id = ?", [pid, id])
      end

      # When an agent last polled the run, waiting on it (acceptance-tests.md, AT-9.12).
      def self.mark_waited(db, id, at)
        db.execute("UPDATE pipeline_runs SET waited_at = ? WHERE id = ?", [at, id])
      end

      # When the run began checking its commit against the trunk (architecture.md, Checking against the trunk).
      def self.trunk_started(db, id, at)
        db.execute("UPDATE pipeline_runs SET trunk_started_at = ? WHERE id = ?", [at.utc.iso8601, id])
      end

      def self.update_status(db, id, new_status)
        now = Time.now.utc.iso8601
        db.execute("UPDATE pipeline_runs SET status = ?, updated_at = ? WHERE id = ?", [new_status, now, id])
      end

      def self.recent(db, limit: 20)
        query(db, "ORDER BY id DESC LIMIT ?", limit)
      end

      # How much a branch whose newest run has a status needs you: a failure most.
      NEEDING = "CASE status WHEN 'failed' THEN 0 WHEN 'timed_out' THEN 1 WHEN 'running' THEN 2 " \
                "WHEN 'scheduled' THEN 3 WHEN 'completed' THEN 4 ELSE 5 END"

      # The newest run of each of `limit` branches: those that most need you,
      # then those run most recently, in that order.
      def self.branch_heads(db, limit:)
        query(db, "WHERE id IN (SELECT MAX(id) FROM pipeline_runs GROUP BY project_path, branch) " \
                  "ORDER BY #{NEEDING}, id DESC LIMIT ?", limit)
      end

      # A project's branch's runs, newest first.
      def self.of_branch(db, project_path, branch, limit:)
        query(db, "WHERE project_path IS ? AND branch = ? ORDER BY id DESC LIMIT ?", project_path, branch, limit)
      end

      def self.query(db, clause, *params)
        db.execute("#{SELECT} #{clause}", params).map { |row| COLUMNS.zip(row).to_h }
      end
      private_class_method :query
    end
  end
end
