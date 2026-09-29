# frozen_string_literal: true

require "time"

module FunCi
  module Persistence
    module StageJob
      TERMINAL_STATUSES = %w[completed failed timed_out cancelled].freeze
      FIELDS = %i[id pipeline_run_id stage status started_at completed_at finished_order output_tail failures
                  exit_status signal budget pruned evidence].freeze
      COLUMNS = FIELDS.join(", ")
      NEXT_IN_RUN = "(SELECT COALESCE(MAX(others.finished_order), 0) + 1 FROM stage_jobs AS others " \
                    "WHERE others.pipeline_run_id = stage_jobs.pipeline_run_id)"
      TIMESTAMP_COLUMNS = TERMINAL_STATUSES.to_h { |status| [status, "completed_at"] }
                                           .merge("running" => "started_at").freeze

      def self.create(db, pipeline_run_id:, stage:, budget: nil)
        db.execute(
          "INSERT INTO stage_jobs (pipeline_run_id, stage, status, budget) VALUES (?, ?, 'scheduled', ?)",
          [pipeline_run_id, stage, budget]
        )
        db.last_insert_row_id
      end

      # The stage script's process, which leads a process group of its own.
      def self.store_pid(db, id, pid)
        db.execute("UPDATE stage_jobs SET pid = ? WHERE id = ?", [pid, id])
      end

      # The end of what the stage printed, kept when it failed (acceptance-tests.md, AT-9.5).
      def self.keep_output(db, id, tail)
        db.execute("UPDATE stage_jobs SET output_tail = ? WHERE id = ?", [tail, id])
      end

      # What was kept about why the stage failed, as JSON (architecture.md, "Evidence of a failed stage").
      def self.keep_evidence(db, id, evidence_json)
        db.execute("UPDATE stage_jobs SET evidence = ? WHERE id = ?", [evidence_json, id])
      end

      # How the stage's process exited: its status, or the signal that ended it.
      def self.keep_exit(db, id, exit_status, signal)
        db.execute("UPDATE stage_jobs SET exit_status = ?, signal = ? WHERE id = ?", [exit_status, signal, id])
      end

      # The other stages of its run that were running at any moment since it started.
      def self.alongside(db, id)
        db.execute("SELECT others.stage FROM stage_jobs AS others JOIN stage_jobs AS me ON me.id = ? " \
                   "WHERE others.pipeline_run_id = me.pipeline_run_id AND others.id != me.id " \
                   "AND others.started_at IS NOT NULL " \
                   "AND (others.completed_at IS NULL OR others.completed_at > me.started_at) ORDER BY others.id",
                   [id]).flatten
      end

      def self.ids(db) = db.execute("SELECT id FROM stage_jobs").flatten

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
                   [new_status, Time.now.utc.iso8601(3), id])
      end

      def self.elapsed_duration(job)
        return nil unless job[:started_at] && job[:completed_at]

        Time.parse(job[:completed_at]) - Time.parse(job[:started_at])
      end

      def self.row_to_hash(row)
        FIELDS.zip(row).to_h
      end
      private_class_method :row_to_hash
    end
  end
end
