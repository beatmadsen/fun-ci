# frozen_string_literal: true

require "sqlite3"

module FunCi
  module Database
    def self.connection(db_path)
      db = SQLite3::Database.new(db_path)
      db.busy_timeout = 5000
      db.execute("PRAGMA journal_mode=WAL")
      db.execute("PRAGMA foreign_keys=ON")
      db
    end

    def self.migrate!(db)
      db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS pipeline_runs (
          id INTEGER PRIMARY KEY,
          commit_hash TEXT,
          branch TEXT,
          status TEXT DEFAULT 'scheduled',
          created_at TEXT,
          updated_at TEXT
        )
      SQL

      db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS stage_jobs (
          id INTEGER PRIMARY KEY,
          pipeline_run_id INTEGER REFERENCES pipeline_runs(id),
          stage TEXT,
          status TEXT DEFAULT 'scheduled',
          started_at TEXT,
          completed_at TEXT
        )
      SQL
    end
  end
end
