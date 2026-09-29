# frozen_string_literal: true

require_relative "pipeline_run"
require_relative "stage_job"
require_relative "run_status"
require_relative "write_trouble"
require "json"
require_relative "null_recorder"
require_relative "project_runs"
require_relative "retention"
require_relative "trunk_recording"

module FunCi
  module Persistence
    class DbRecorder
      include TrunkRecording

      KEPT_RUNS = Retention::KEPT_RUNS

      attr_reader :db, :db_path, :pipeline_run_id, :trouble

      def self.for_background(db_path, pipeline_run_id, trouble: WriteTrouble.silent(db_path))
        db = Database.connection(db_path)
        new(db, pipeline_run_id: pipeline_run_id, trouble: trouble)
      end

      # `trouble` decides what a refused write does; by default, nothing is said.
      def initialize(db, pipeline_run_id: nil, trouble: nil)
        @db = db
        @db_path = db.filename("main")
        @pipeline_run_id = pipeline_run_id
        @trouble = trouble || WriteTrouble.silent(@db_path)
      end

      # Says what goes wrong writing to the database on `out` from now on.
      def report_trouble_to(out)
        @trouble = WriteTrouble.new(out, @db_path)
      end

      # The block's value, or nil when the database refused a write in it.
      def tolerating(&) = @trouble.guard(&)

      def close
        @db.close
      rescue StandardError
        nil
      end

      # Notes this process as the one running the pipeline, so cancelling can stop it.
      def create_run(commit_hash:, branch:, project_path: nil)
        tolerating do
          @pipeline_run_id = PipelineRun.create(@db, commit_hash: commit_hash, branch: branch,
                                                     project_path: project_path)
          PipelineRun.store_trigger_pid(@db, @pipeline_run_id, Process.pid)
          Retention.apply(@db, project_path) if project_path
          @pipeline_run_id
        end
      end

      def stage_process(job_id, pid)
        tolerating { StageJob.store_pid(@db, job_id, pid) }
      end

      # Once it has exited its pid may be reused, so a cancel must not signal it.
      def foreground_done
        tolerating { PipelineRun.store_trigger_pid(@db, @pipeline_run_id, nil) }
      end

      def slot_taken(lock_file)
        tolerating { PipelineRun.store_slot_lock(@db, @pipeline_run_id, lock_file) }
      end

      def start_stage(stage, budget: nil)
        return nil unless @pipeline_run_id

        tolerating do
          ensure_running
          job_id = StageJob.create(@db, pipeline_run_id: @pipeline_run_id, stage: stage, budget: budget)
          StageJob.update_status(@db, job_id, "running")
          job_id
        end
      end

      # Keeps a failed stage's evidence, and the output's tail where an older
      # fun-ci sharing the database reads it.
      def keep_evidence(job_id, document)
        tolerating do
          StageJob.keep_evidence(@db, job_id, JSON.generate(document.to_h))
          StageJob.keep_output(@db, job_id, document.tail)
        end
      end

      # Keeps what a failed stage printed, masked and cut to its window.
      def keep_raw(job_id, text)
        tolerating { RawOutputs.beside(@db_path).write(job_id, text) }
      end

      # The stages that shared the slot with this one (architecture.md, "Evidence of a failed stage").
      def alongside(job_id) = tolerating { StageJob.alongside(@db, job_id) } || []

      def keep_exit(job_id, exit_status, signal)
        tolerating { StageJob.keep_exit(@db, job_id, exit_status, signal) }
      end

      # Records the stage's outcome, then settles the run's status from its stages.
      def end_stage(job_id, status)
        tolerating do
          StageJob.update_status(@db, job_id, status)
          RunStatus.settle(@db, @pipeline_run_id)
        end
      end

      private

      def ensure_running
        run = PipelineRun.find(@db, @pipeline_run_id)
        return unless run && run[:status] == "scheduled"

        PipelineRun.update_status(@db, @pipeline_run_id, "running")
      end
    end
  end
end
