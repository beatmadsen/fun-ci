# frozen_string_literal: true

require_relative "../persistence/database"
require_relative "../persistence/pipeline_recorder"
require_relative "background_wrapper"

module FunCi
  module Pipeline
    class PipelineForker
      def self.fork_pipeline(commit_hash:, branch:, db_path:)
        pid = fork do
          run_in_child(commit_hash: commit_hash, branch: branch, db_path: db_path)
        end
        Process.detach(pid)
      end

      def self.run_in_child(commit_hash:, branch:, db_path:)
        db = Persistence::Database.connection(db_path)
        recorder = Persistence::DbRecorder.new(db)
        Trigger.new(
          project_root: Dir.pwd,
          commit_hash: commit_hash,
          branch: branch,
          stdout: File.open(File::NULL, "w"),
          recorder: recorder,
          background_launcher: method(:sync_launcher)
        ).run
        recorder.close
      end

      def self.sync_launcher(db_path:, pipeline_run_id:, job_id:, executor:)
        recorder = Persistence::DbRecorder.for_background(db_path, pipeline_run_id)
        BackgroundWrapper.new(recorder: recorder, job_id: job_id, executor: executor).run
        recorder.close
      end
    end
  end
end
