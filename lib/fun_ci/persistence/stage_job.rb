# frozen_string_literal: true

require "time"

module FunCi
  module Persistence
    module StageJob
      TERMINAL_STATUSES = %w[completed failed timed_out cancelled].freeze
      COLUMNS = "id, pipeline_run_id, stage, status, started_at, completed_at"
      TIMESTAMP_COLUMNS = TERMINAL_STATUSES.to_h { |status| [status, "completed_at"] }
                                           .merge("running" => "started_at").freeze

      def self.create(db, pipeline_run_id:, stage:)
        db.execute(
          "INSERT INTO stage_jobs (pipeline_run_id, stage, status) VALUES (?, ?, 'scheduled')",
          [pipeline_run_id, stage]
        )
        db.last_insert_row_id
      end

      # The stage script's process, which leads a process group of its own.
      def self.store_pid(db, id, pid)
        db.execute("UPDATE stage_jobs SET pid = ? WHERE id = ?", [pid, id])
      end

      def self.find(db, id)
        row = db.execute("SELECT #{COLUMNS} FROM stage_jobs WHERE id = ?", [id]).first
        return nil unless row

        row_to_hash(row)
      end

      # The run's jobs, in the order they were created.
      def self.for_run(db, pipeline_run_id)
        db.execute("SELECT #{COLUMNS} FROM stage_jobs WHERE pipeline_run_id = ? ORDER BY id", [pipeline_run_id])
          .map { |row| row_to_hash(row) }
      end

      def self.update_status(db, id, new_status)
        column = TIMESTAMP_COLUMNS.fetch(new_status)
        now = Time.now.utc.iso8601
        db.execute("UPDATE stage_jobs SET status = ?, #{column} = ? WHERE id = ?", [new_status, now, id])
      end

      def self.elapsed_duration(job)
        return nil unless job[:started_at] && job[:completed_at]

        Time.parse(job[:completed_at]) - Time.parse(job[:started_at])
      end

      def self.row_to_hash(row)
        { id: row[0], pipeline_run_id: row[1], stage: row[2], status: row[3], started_at: row[4], completed_at: row[5] }
      end
      private_class_method :row_to_hash
    end
  end
end
