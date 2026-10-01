# frozen_string_literal: true

require "json"
require "time"
require_relative "raw_outputs"

module FunCi
  module Persistence
    # Records a daily or weekly job's run as it runs, through the calls
    # Pipeline::StageExecution makes of a stage's recorder, so a job's
    # evidence is collected as a stage's is (architecture.md, Daily and
    # weekly jobs). `id` is the job run's.
    class JobRecorder
      def initialize(db)
        @db = db
      end

      # The process that runs the job, which a cancel stops first, and the budget it runs to.
      def started_by(id, pid, budget: nil) = set(id, pid: pid, budget: budget)

      # The job's script, which leads a process group of its own.
      def stage_process(id, pid) = set(id, group_pid: pid)

      # Unless the run was cancelled meanwhile.
      def end_stage(id, status)
        @db.execute("UPDATE job_runs SET status = ?, completed_at = ? WHERE id = ? AND status = 'running'",
                    [status, Time.now.utc.iso8601(3), id])
      end

      # And the output's last lines, as a stage keeps them.
      def keep_evidence(id, document) = set(id, evidence: JSON.generate(document.to_h), output_tail: document.tail)

      def keep_exit(id, exit_status, signal) = set(id, exit_status: exit_status, signal: signal)
      def keep_raw(id, text) = RawOutputs.for_jobs(@db.filename("main")).write(id, text)

      # No stage shares a job's worktree.
      def alongside(_id) = []

      private

      def set(id, **values)
        @db.execute("UPDATE job_runs SET #{values.keys.map { |column| "#{column} = ?" }.join(", ")} WHERE id = ?",
                    [*values.values, id])
      end
    end
  end
end
