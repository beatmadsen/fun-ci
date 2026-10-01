# frozen_string_literal: true

require_relative "trigger_params"
require_relative "pipeline_forker"

module FunCi
  module Pipeline
    # `fun-ci trigger [--background] <commit-hash> <branch>`. --no-validate is
    # the 1.x name for --background, kept until 3.0.
    class TriggerCommand
      BACKGROUND = %w[--background --no-validate].freeze
      DEPRECATED = "fun-ci: --no-validate is now --background; the old name goes in 3.0."

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

      # The forker answers whether it started a run; one that did says how an
      # agent gets its verdict (acceptance-tests.md, AT-9.14), and what the
      # forker says of a first fetch of the trunk.
      def fork_pipeline(commit)
        db_path = @recorder.db_path
        @recorder.close
        forked = @pipeline_forker.call(commit_hash: commit.sha, branch: commit.branch, db_path: db_path)
        return 0 unless forked

        say_how_to_wait(commit.sha[0, 7])
        say(forked)
        0
      end

      # The config's mistakes and the first fetch's notice, and on stderr, why
      # the jobs didn't start; the run itself prints nowhere.
      def say(forked)
        Setup::ProjectConfig.new(@project).settings_errors.each { |e| @io.stdout.puts "fun-ci: #{e}" }
        @io.stdout.puts(forked.notice) if forked.notice
        @io.stderr.puts(forked.jobs) if forked.jobs
      end

      def say_how_to_wait(sha)
        @io.stdout.puts("fun-ci: testing #{sha}. Verdict: fun-ci wait #{sha} --need all --follow-branch")
      end
    end
  end
end
