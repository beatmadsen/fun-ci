# frozen_string_literal: true

require_relative "../persistence/pipeline_recorder"
require_relative "../persistence/pipeline_run"
require_relative "background_wrapper"

module FunCi
  module Pipeline
    # Runs the slow suite in a forked child. A child must not inherit an open
    # SQLite connection, so the parent's recorder is closed before the fork and
    # #launch answers a fresh one for the parent to carry on with. The slot was
    # shared for the slow suite before the fork; after it, each process drops
    # the other's share and keeps its own.
    class BackgroundFork
      def initialize(recorder, slot)
        @recorder = recorder
        @slot = slot
      end

      def launch(db_path:, pipeline_run_id:, job_id:, executor:)
        @recorder.close
        pid = fork { run_in_child(db_path, pipeline_run_id, job_id, executor) }
        @slot.release
        Process.detach(pid)
        reopened = Persistence::DbRecorder.for_background(db_path, pipeline_run_id)
        Persistence::PipelineRun.store_pid(reopened.db, pipeline_run_id, pid)
        reopened
      end

      private

      # Records its own pid before the slow suite starts, so a cancel can't
      # miss it; the parent records it too, for its callers.
      def run_in_child(db_path, pipeline_run_id, job_id, executor)
        @slot.release
        recorder = Persistence::DbRecorder.for_background(db_path, pipeline_run_id)
        Persistence::PipelineRun.store_pid(recorder.db, pipeline_run_id, Process.pid)
        BackgroundWrapper.new(recorder: recorder, job_id: job_id, executor: executor).run
        recorder.close
      end
    end
  end
end
