# frozen_string_literal: true

require_relative "../persistence/pipeline_recorder"
require_relative "../persistence/pipeline_run"
require_relative "background_wrapper"

module FunCi
  module Pipeline
    # Runs the slow suite in a forked child. A child must not inherit an open
    # SQLite connection, so the parent's recorder is closed before the fork and
    # #launch answers a fresh one for the parent to carry on with.
    class BackgroundFork
      def initialize(recorder)
        @recorder = recorder
      end

      def launch(db_path:, pipeline_run_id:, job_id:, executor:)
        @recorder.close
        pid = fork { run_in_child(db_path, pipeline_run_id, job_id, executor) }
        reopened = Persistence::DbRecorder.for_background(db_path, pipeline_run_id)
        Process.detach(pid)
        Persistence::PipelineRun.store_pid(reopened.db, pipeline_run_id, pid)
        reopened
      end

      private

      def run_in_child(db_path, pipeline_run_id, job_id, executor)
        recorder = Persistence::DbRecorder.for_background(db_path, pipeline_run_id)
        BackgroundWrapper.new(recorder: recorder, job_id: job_id, executor: executor).run
        recorder.close
      end
    end
  end
end
