# frozen_string_literal: true

require_relative "../persistence/database"
require_relative "../persistence/pipeline_recorder"
require_relative "trigger_params"
require_relative "../setup/project_config"

module FunCi
  module Pipeline
    class PipelineForker
      # Answers whether it started a run: none in a project not set up for fun-ci.
      def self.fork_pipeline(commit_hash:, branch:, db_path:)
        return false unless Setup::ProjectConfig.new(Dir.pwd).validate.empty?

        pid = fork do
          run_in_child(commit_hash: commit_hash, branch: branch, db_path: db_path)
        end
        Process.detach(pid)
      end

      def self.run_in_child(commit_hash:, branch:, db_path:)
        recorder = Persistence::DbRecorder.new(Persistence::Database.connection(db_path))
        trigger = trigger(commit_hash, branch, recorder)
        trigger.run
        trigger.close
      end

      def self.trigger(commit_hash, branch, recorder)
        Trigger.new(project: Dir.pwd, commit: Commit.new(sha: commit_hash, branch: branch),
                    io: Io.new(stdout: File.open(File::NULL, "w")),
                    seams: Seams.new(recorder: recorder, background_launcher: method(:sync_launcher)))
      end
      private_class_method :trigger

      def self.sync_launcher(db_path:, pipeline_run_id:, job_id:, executor:)
        recorder = Persistence::DbRecorder.for_background(db_path, pipeline_run_id)
        executor.call(recorder, job_id)
        recorder.close
      end
    end
  end
end
