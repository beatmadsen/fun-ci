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

      # One row per commit and trunk SHA, written once (architecture.md, Checking against the trunk).
      TRUNK_CHECKS_TABLE = <<~SQL
        CREATE TABLE IF NOT EXISTS trunk_checks (
          id INTEGER PRIMARY KEY,
          project_path TEXT, commit_hash TEXT, trunk_remote TEXT, trunk_branch TEXT, trunk_sha TEXT,
          trunk_seen_at TEXT, checked_at TEXT,
          outcome TEXT, ahead INTEGER, behind INTEGER, files TEXT, reason TEXT,
          UNIQUE (project_path, commit_hash, trunk_sha)
        )
      SQL

      # When fun-ci last fetched each project's trunk (architecture.md, Checking against the trunk).
      TRUNK_FETCHES_TABLE = <<~SQL
        CREATE TABLE IF NOT EXISTS trunk_fetches (
          project_path TEXT PRIMARY KEY, claimed_at INTEGER, fetched_at TEXT, failures INTEGER, error TEXT
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
                       %w[stage_jobs pid INTEGER], %w[stage_jobs finished_order INTEGER],
                       %w[stage_jobs output_tail TEXT], %w[stage_jobs failures TEXT],
                       %w[pipeline_runs waited_at TEXT], %w[stage_jobs exit_status INTEGER],
                       %w[stage_jobs signal TEXT], %w[stage_jobs budget INTEGER], %w[stage_jobs pruned INTEGER],
                       %w[stage_jobs evidence TEXT], %w[pipeline_runs fetch_pgid INTEGER],
                       %w[pipeline_runs trunk_started_at TEXT]].freeze

      def self.migrate!(db)
        with_setup_lock(db.filename("main")) do
          [PIPELINE_RUNS_TABLE, STAGE_JOBS_TABLE, TRUNK_CHECKS_TABLE, TRUNK_FETCHES_TABLE].each do |table|
            db.execute(table)
          end
          ADDED_COLUMNS.each { |table, column, type| add_column_if_missing(db, table, column, type) }
          db.execute(NAME_DETACHED)
        end
      end

      # Runs started on a detached HEAD before 2.0.1 were kept with no branch name.
      NAME_DETACHED = "UPDATE pipeline_runs SET branch = 'detached' WHERE branch = ''"

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
