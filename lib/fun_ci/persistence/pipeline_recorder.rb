# frozen_string_literal: true

require_relative "pipeline_run"
require_relative "stage_job"
require_relative "run_status"
require_relative "write_trouble"

module FunCi
  module Persistence
    class NullRecorder
      def create_run(**) = nil
      def start_stage(_stage) = nil
      def end_stage(_job_id, _status) = nil
      def stage_process(_job_id, _pid) = nil
      def slot_taken(_lock_file) = nil
      def foreground_done = nil
      def db = nil
      def db_path = nil
      def pipeline_run_id = nil
      def close = nil
      def tolerating = yield
      def report_trouble_to(_out) = nil
    end

    class DbRecorder
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

      def start_stage(stage)
        return nil unless @pipeline_run_id

        tolerating do
          ensure_running
          job_id = StageJob.create(@db, pipeline_run_id: @pipeline_run_id, stage: stage)
          StageJob.update_status(@db, job_id, "running")
          job_id
        end
      end

      # Without a run there is no job and no row to update, so these write nothing.
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
