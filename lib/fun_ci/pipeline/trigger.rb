# frozen_string_literal: true

require_relative "../setup/project_config"
require_relative "../persistence/pipeline_recorder"
require_relative "trigger_params"
require_relative "trigger_command"
require_relative "slot_run"
require_relative "stale_pipeline_canceller"
require_relative "worktree_pool"
require_relative "in_place"

module FunCi
  module Pipeline
    class Trigger
      NULL_SHA = ("0" * 40).freeze

      def self.run_from_args(args, io: Io.new, recorder: Persistence::NullRecorder.new, pipeline_forker: nil)
        TriggerCommand.new(io: io, recorder: recorder, pipeline_forker: pipeline_forker).run(args)
      end

      def initialize(project:, commit:, io: Io.new, seams: Seams.new)
        @project = project
        @commit = commit
        @io = io
        @seams = seams
      end

      def run
        config = Setup::ProjectConfig.new(@project)
        return handle_config_errors(config) if config.validate.any?
        return unknown_commit unless known_commit?

        start_run
        run_in(workspace.acquire(@commit.sha))
      end

      # The background launcher swaps in a fresh recorder after forking, so
      # callers release the connection through the trigger, not their own copy.
      def close
        recorder.close
      end

      private

      def recorder = @seams.recorder
      def known_commit? = @commit.sha == NULL_SHA || @seams.commit_validator.call(@commit.sha)

      def workspace
        return @seams.workspace if @seams.workspace
        return InPlace.new(@project) if @commit.sha == NULL_SHA

        WorktreePool.new(Worktrees.new(@project))
      end

      # The scripts come from the commit when it has them, so they match the
      # code they test; a project that keeps .fun-ci/ out of git uses its own.
      def config_for(slot)
        committed = Setup::ProjectConfig.new(slot.path)
        committed.folder_exists? ? committed : Setup::ProjectConfig.new(@project)
      end

      def handle_config_errors(config)
        config.validate.each { |e| @io.stdout.puts "fun-ci: #{e}" }
        unless config.folder_exists?
          @io.stdout.puts "Create .fun-ci/lint.sh, build.sh, fast.sh, and slow.sh to set up this project."
          @io.stdout.puts "Commit will proceed without CI."
        end
        0
      end

      def unknown_commit
        @io.stderr.puts "fun-ci: commit #{@commit.sha} not found in this repository."
        1
      end

      def start_run
        cancel_stale_pipelines
        recorder.create_run(commit_hash: @commit.sha, branch: @commit.branch, project_path: @project)
      end

      # After forking the slow suite the run holds a recorder of its own.
      def run_in(slot)
        slot_run = SlotRun.new(commit: @commit, io: @io, seams: @seams, slot: slot)
        slot_run.run(config_for(slot)).tap { @seams = slot_run.seams }
      end

      def cancel_stale_pipelines
        return unless recorder.db

        StalePipelineCanceller.new(db: recorder.db, branch: @commit.branch, stdout: @io.stdout)
                              .cancel(new_commit_hash: @commit.sha)
      end
    end
  end
end
