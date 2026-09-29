# frozen_string_literal: true

require_relative "trunk_recording"

module FunCi
  module Persistence
    # Records nothing, for a pipeline run with no database.
    class NullRecorder
      def create_run(**); end
      def start_stage(_stage, **); end
      def end_stage(_job_id, _status); end
      def keep_exit(_job_id, _exit_status, _signal); end
      def keep_evidence(_job_id, _document); end
      def keep_raw(_job_id, _text); end
      def trunk_checked(_check); end
      def trunk_fetched(_fetched, _tip); end
      def trunk_fetch_process(_pgid); end
      def trunk_check_started; end
      def trunk_heads(**) = {}
      def trunk_fetches = TrunkRecording::NoFetches.new
      def alongside(_job_id) = []
      def stage_process(_job_id, _pid); end
      def slot_taken(_lock_file); end
      def foreground_done; end
      def db; end
      def db_path; end
      def pipeline_run_id; end
      def close; end
      def tolerating = yield
      def report_trouble_to(_out); end
    end
  end
end
