# frozen_string_literal: true

require_relative "pipeline_run"
require_relative "stage_job"

module FunCi
  module Persistence
    class NullRecorder
      def create_run(**) = nil
      def start_stage(_stage) = nil
      def end_stage(_job_id, _status) = nil
      def stage_process(_job_id, _pid) = nil
      def slot_taken(_lock_file) = nil
      def complete_run = nil
      def fail_run = nil
      def db = nil
      def db_path = nil
      def pipeline_run_id = nil
      def close = nil
    end

    class DbRecorder
      attr_reader :db, :db_path, :pipeline_run_id

      def self.for_background(db_path, pipeline_run_id)
        db = Database.connection(db_path)
        new(db, pipeline_run_id: pipeline_run_id)
      end

      def initialize(db, pipeline_run_id: nil)
        @db = db
        @db_path = db.filename("main")
        @pipeline_run_id = pipeline_run_id
      end

      def close
        @db.close
      rescue StandardError
        nil
      end

      # Notes this process as the one running the pipeline, so cancelling can stop it.
      def create_run(commit_hash:, branch:, project_path: nil)
        @pipeline_run_id = PipelineRun.create(@db, commit_hash: commit_hash, branch: branch, project_path: project_path)
        PipelineRun.store_trigger_pid(@db, @pipeline_run_id, Process.pid)
        @pipeline_run_id
      end

      def stage_process(job_id, pid)
        StageJob.store_pid(@db, job_id, pid)
      end

      def slot_taken(lock_file)
        PipelineRun.store_slot_lock(@db, @pipeline_run_id, lock_file)
      end

      def start_stage(stage)
        return nil unless @pipeline_run_id

        ensure_running
        job_id = StageJob.create(@db, pipeline_run_id: @pipeline_run_id, stage: stage)
        StageJob.update_status(@db, job_id, "running")
        job_id
      end

      # Without a run there is no job and no row to update, so these write nothing.
      def end_stage(job_id, status)
        StageJob.update_status(@db, job_id, status)
      end

      def complete_run
        PipelineRun.update_status(@db, @pipeline_run_id, "completed")
      end

      def fail_run
        PipelineRun.update_status(@db, @pipeline_run_id, "failed")
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
