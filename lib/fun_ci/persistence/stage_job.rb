# frozen_string_literal: true

require "time"

module FunCi
  module Persistence
    module StageJob
      TERMINAL_STATUSES = %w[completed failed timed_out cancelled].freeze

      def self.create(db, pipeline_run_id:, stage:)
        db.execute(
          "INSERT INTO stage_jobs (pipeline_run_id, stage, status) VALUES (?, ?, 'scheduled')",
          [pipeline_run_id, stage]
        )
        db.last_insert_row_id
      end

      def self.find(db, id)
        row = db.execute("SELECT id, pipeline_run_id, stage, status, started_at, completed_at FROM stage_jobs WHERE id = ?", [id]).first
        return nil unless row
        row_to_hash(row)
      end

      def self.update_status(db, id, new_status)
        now = Time.now.utc.iso8601
        if new_status == "running"
          db.execute("UPDATE stage_jobs SET status = ?, started_at = ? WHERE id = ?", [new_status, now, id])
        elsif TERMINAL_STATUSES.include?(new_status)
          db.execute("UPDATE stage_jobs SET status = ?, completed_at = ? WHERE id = ?", [new_status, now, id])
        else
          db.execute("UPDATE stage_jobs SET status = ? WHERE id = ?", [new_status, id])
        end
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
