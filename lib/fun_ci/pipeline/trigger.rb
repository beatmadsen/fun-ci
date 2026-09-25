# frozen_string_literal: true

require_relative "../setup/project_config"
require_relative "../persistence/pipeline_recorder"
require_relative "trigger_params"
require_relative "trigger_command"
require_relative "background_fork"
require_relative "stage_runner"
require_relative "stale_pipeline_canceller"
require_relative "progress_reporter"

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
        run_stages(config)
      end

      # The background launcher swaps in a fresh recorder after forking, so
      # callers release the connection through the trigger, not their own copy.
      def close
        recorder.close
      end

      private

      def recorder = @seams.recorder
      def stage_runner = StageRunner.new(commit_hash: @commit.sha, stdout: @io.stdout, seams: @seams)
      def progress = ProgressReporter.new(stdout: @io.stdout)
      def known_commit? = @commit.sha == NULL_SHA || @seams.commit_validator.call(@commit.sha)

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

      def run_stages(config)
        return fail_run unless phase_one_passed?(config)

        launch_slow_suite(config)
        progress.slow_launched
        fast_passed?(config) ? 0 : fail_run
      end

      def phase_one_passed?(config)
        results = %w[lint build].to_h { |stage| [stage, Thread.new { stage_runner.passes?(config, stage) }] }
                                .transform_values(&:value)
        progress.phase_one_result(results)
        results.values.all?
      end

      def fast_passed?(config)
        passed = stage_runner.passes?(config, "fast")
        progress.fast_result(passed)
        passed
      end

      def fail_run
        recorder.fail_run
        1
      end

      def launch_slow_suite(config)
        cmd = "#{config.script_path("slow")} #{@commit.sha}"
        executor = @seams.executor
        budget = @seams.budgets["slow"]
        launch(db_path: recorder.db_path, pipeline_run_id: recorder.pipeline_run_id,
               job_id: recorder.start_stage("slow"), executor: -> { executor.call(cmd, budget) })
      end

      def launch(**)
        return @seams.background_launcher.call(**) if @seams.background_launcher

        @seams = @seams.with(recorder: BackgroundFork.new(recorder).launch(**))
      end

      def cancel_stale_pipelines
        return unless recorder.db

        StalePipelineCanceller.new(db: recorder.db, branch: @commit.branch, stdout: @io.stdout)
                              .cancel(new_commit_hash: @commit.sha)
      end
    end
  end
end
