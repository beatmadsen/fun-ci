# frozen_string_literal: true

require "time"

module FunCi
  module Persistence
    module PipelineRun
      COLUMNS = %i[id commit_hash branch status pid project_path created_at updated_at].freeze
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

      def self.store_pid(db, id, pid)
        db.execute("UPDATE pipeline_runs SET pid = ? WHERE id = ?", [pid, id])
      end

      def self.find_running_with_pid(db, branch)
        query(db, "WHERE branch = ? AND status = 'running' AND pid IS NOT NULL ORDER BY id DESC LIMIT 1", branch).first
      end

      def self.update_status(db, id, new_status)
        now = Time.now.utc.iso8601
        db.execute("UPDATE pipeline_runs SET status = ?, updated_at = ? WHERE id = ?", [new_status, now, id])
      end

      def self.recent(db, limit: 20)
        query(db, "ORDER BY id DESC LIMIT ?", limit)
      end

      def self.query(db, clause, param)
        db.execute("#{SELECT} #{clause}", [param]).map { |row| COLUMNS.zip(row).to_h }
      end
      private_class_method :query
    end
  end
end
