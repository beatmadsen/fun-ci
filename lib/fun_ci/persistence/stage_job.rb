# frozen_string_literal: true

require "time"

module FunCi
  module Persistence
    module StageJob
      TERMINAL_STATUSES = %w[completed failed timed_out cancelled].freeze
      COLUMNS = "id, pipeline_run_id, stage, status, started_at, completed_at, finished_order"
      NEXT_IN_RUN = "(SELECT COALESCE(MAX(others.finished_order), 0) + 1 FROM stage_jobs AS others " \
                    "WHERE others.pipeline_run_id = stage_jobs.pipeline_run_id)"
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

      # A stage that finishes is numbered after every other of its run that
      # finished before it, in the same statement, so the order holds however
      # close together they finished.
      def self.update_status(db, id, new_status)
        column = TIMESTAMP_COLUMNS.fetch(new_status)
        order = TERMINAL_STATUSES.include?(new_status) ? NEXT_IN_RUN : "finished_order"
        db.execute("UPDATE stage_jobs SET status = ?, #{column} = ?, finished_order = #{order} WHERE id = ?",
                   [new_status, Time.now.utc.iso8601, id])
      end

      def self.elapsed_duration(job)
        return nil unless job[:started_at] && job[:completed_at]

        Time.parse(job[:completed_at]) - Time.parse(job[:started_at])
      end

      def self.row_to_hash(row)
        %i[id pipeline_run_id stage status started_at completed_at finished_order].zip(row).to_h
      end
      private_class_method :row_to_hash
    end
  end
end
