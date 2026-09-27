# frozen_string_literal: true

module FunCi
  module Persistence
    # Records nothing, for a pipeline run with no database.
    class NullRecorder
      def create_run(**) = nil
      def start_stage(_stage, **) = nil
      def end_stage(_job_id, _status) = nil
      def keep_exit(_job_id, _exit_status, _signal) = nil
      def keep_evidence(_job_id, _document) = nil
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
  end
end
