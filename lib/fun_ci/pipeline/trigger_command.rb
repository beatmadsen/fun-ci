# frozen_string_literal: true

require_relative "trigger_params"
require_relative "pipeline_forker"

module FunCi
  module Pipeline
    # `fun-ci trigger [--background] <commit-hash> <branch>`. --no-validate is
    # the 1.x name for --background, kept for one release.
    class TriggerCommand
      BACKGROUND = %w[--background --no-validate].freeze
      DEPRECATED = "fun-ci: --no-validate is now --background; the old name goes in 2.1."

      def initialize(io:, recorder:, pipeline_forker:, project: Dir.pwd)
        @io = io
        @recorder = recorder
        @pipeline_forker = pipeline_forker || PipelineForker.method(:fork_pipeline)
        @project = project
      end

      # Closes the database connection it was given on every path.
      def run(args)
        sha, branch = args.reject { |a| a.start_with?("--") }
        return usage unless branch

        @io.stderr.puts DEPRECATED if args.include?("--no-validate")
        commit = Commit.new(sha: sha, branch: branch)
        args.intersect?(BACKGROUND) ? fork_pipeline(commit) : run_pipeline(commit)
      ensure
        @recorder.close
      end

      private

      # After forking the slow suite the trigger holds a recorder of its own.
      def run_pipeline(commit)
        trigger = Trigger.new(project: @project, commit: commit, io: @io, seams: Seams.new(recorder: @recorder))
        trigger.run
      ensure
        trigger&.close
      end

      def usage
        @io.stderr.puts "fun-ci: commit hash and branch name are required."
        @io.stderr.puts "Usage: fun-ci trigger <commit-hash> <branch>"
        1
      end

      def fork_pipeline(commit)
        db_path = @recorder.db_path
        @recorder.close
        @pipeline_forker.call(commit_hash: commit.sha, branch: commit.branch, db_path: db_path)
        0
      end
    end
  end
end
