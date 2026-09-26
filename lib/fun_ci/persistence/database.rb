# frozen_string_literal: true

require "sqlite3"

module FunCi
  module Persistence
    module Database
      PIPELINE_RUNS_TABLE = <<~SQL
        CREATE TABLE IF NOT EXISTS pipeline_runs (
          id INTEGER PRIMARY KEY,
          commit_hash TEXT,
          branch TEXT,
          status TEXT DEFAULT 'scheduled',
          pid INTEGER,
          created_at TEXT,
          updated_at TEXT
        )
      SQL

      STAGE_JOBS_TABLE = <<~SQL
        CREATE TABLE IF NOT EXISTS stage_jobs (
          id INTEGER PRIMARY KEY,
          pipeline_run_id INTEGER REFERENCES pipeline_runs(id),
          stage TEXT,
          status TEXT DEFAULT 'scheduled',
          started_at TEXT,
          completed_at TEXT
        )
      SQL

      # Opening and migrating hold an exclusive lock on a file beside the
      # database, so fun-ci processes starting at once set it up one at a time.
      # SQLite's busy timeout doesn't cover the switch to WAL, and a column can
      # appear between one process's check and its ALTER.
      def self.connection(db_path, open: SQLite3::Database.method(:new))
        with_setup_lock(db_path) { configure(open.call(db_path)) }
      end

      # Columns added after the tables were first released, so older
      # databases gain them on the next migrate!.
      ADDED_COLUMNS = [%w[pipeline_runs pid INTEGER], %w[pipeline_runs project_path TEXT],
                       %w[pipeline_runs trigger_pid INTEGER], %w[pipeline_runs slot_lock TEXT],
                       %w[stage_jobs pid INTEGER], %w[stage_jobs finished_order INTEGER]].freeze

      def self.migrate!(db)
        with_setup_lock(db.filename("main")) do
          [PIPELINE_RUNS_TABLE, STAGE_JOBS_TABLE].each { |table| db.execute(table) }
          ADDED_COLUMNS.each { |table, column, type| add_column_if_missing(db, table, column, type) }
        end
      end

      def self.with_setup_lock(db_path)
        File.open("#{db_path}.setup-lock", File::RDWR | File::CREAT, 0o644) do |lock|
          lock.flock(File::LOCK_EX)
          yield
        end
      end
      private_class_method :with_setup_lock

      def self.configure(db)
        db.busy_timeout = 5000
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA foreign_keys=ON")
        db
      end
      private_class_method :configure

      def self.add_column_if_missing(db, table, column, type)
        columns = db.execute("PRAGMA table_info(#{table})").map { |row| row[1] }
        return if columns.include?(column)

        db.execute("ALTER TABLE #{table} ADD COLUMN #{column} #{type}")
      end
      private_class_method :add_column_if_missing
    end
  end
end
