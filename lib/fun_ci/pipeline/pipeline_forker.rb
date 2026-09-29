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

      # Trigger requires this file, through TriggerCommand, so it is loaded
      # here, where it is used, rather than above.
      def self.run_in_child(commit_hash:, branch:, db_path:)
        require_relative "trigger"
        recorder = Persistence::DbRecorder.new(Persistence::Database.connection(db_path))
        trigger = trigger(commit_hash, branch, recorder)
        trigger.run
        trigger.close
      end

      # The slow suite forks from here as it does in the foreground, so the
      # fast suite, whose verdict a push waits for, runs beside it.
      def self.trigger(commit_hash, branch, recorder)
        Trigger.new(project: Dir.pwd, commit: Commit.new(sha: commit_hash, branch: branch),
                    io: Io.new(stdout: File.open(File::NULL, "w")), seams: Seams.new(recorder: recorder))
      end
      private_class_method :trigger
    end
  end
end
