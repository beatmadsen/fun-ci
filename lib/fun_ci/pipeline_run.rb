# frozen_string_literal: true

require "time"

module FunCi
  module PipelineRun
    def self.create(db, commit_hash:, branch:, project_path: nil)
      now = Time.now.utc.iso8601
      db.execute(
        "INSERT INTO pipeline_runs (commit_hash, branch, project_path, status, created_at, updated_at) VALUES (?, ?, ?, 'scheduled', ?, ?)",
        [commit_hash, branch, project_path, now, now]
      )
      db.last_insert_row_id
    end

    def self.find(db, id)
      row = db.execute("SELECT id, commit_hash, branch, status, pid, project_path, created_at, updated_at FROM pipeline_runs WHERE id = ?", [id]).first
      return nil unless row
      row_to_hash(row)
    end

    def self.find_by_branch(db, branch)
      rows = db.execute("SELECT id, commit_hash, branch, status, pid, project_path, created_at, updated_at FROM pipeline_runs WHERE branch = ? ORDER BY id DESC", [branch])
      rows.map { |row| row_to_hash(row) }
    end

    def self.find_by_commit(db, commit_hash)
      rows = db.execute("SELECT id, commit_hash, branch, status, pid, project_path, created_at, updated_at FROM pipeline_runs WHERE commit_hash = ? ORDER BY id DESC", [commit_hash])
      rows.map { |row| row_to_hash(row) }
    end

    def self.store_pid(db, id, pid)
      db.execute("UPDATE pipeline_runs SET pid = ? WHERE id = ?", [pid, id])
    end

    def self.find_running_with_pid(db, branch)
      row = db.execute("SELECT id, commit_hash, branch, status, pid, project_path, created_at, updated_at FROM pipeline_runs WHERE branch = ? AND status = 'running' AND pid IS NOT NULL ORDER BY id DESC LIMIT 1", [branch]).first
      return nil unless row
      row_to_hash(row)
    end

    def self.update_status(db, id, new_status)
      now = Time.now.utc.iso8601
      db.execute("UPDATE pipeline_runs SET status = ?, updated_at = ? WHERE id = ?", [new_status, now, id])
    end

    def self.recent(db, limit: 20)
      rows = db.execute("SELECT id, commit_hash, branch, status, pid, project_path, created_at, updated_at FROM pipeline_runs ORDER BY id DESC LIMIT ?", [limit])
      rows.map { |row| row_to_hash(row) }
    end

    def self.row_to_hash(row)
      { id: row[0], commit_hash: row[1], branch: row[2], status: row[3], pid: row[4], project_path: row[5], created_at: row[6], updated_at: row[7] }
    end
    private_class_method :row_to_hash
  end
end
