# frozen_string_literal: true

require_relative "trigger_params"
require_relative "background_fork"
require_relative "stage_runner"
require_relative "stage_execution"
require_relative "progress_reporter"

module FunCi
  module Pipeline
    # The stages of one pipeline, run in the slot it was given: lint and build
    # side by side, then the slow suite in the background while the fast suite
    # runs. The slot frees when the last stage holding it finishes.
    class SlotRun
      attr_reader :seams

      def initialize(commit:, io:, seams:, slot:)
        @commit = commit
        @io = io
        @seams = seams
        @slot = slot
      end

      def run(config)
        recorder.slot_taken(@slot.lock_file) if @slot.lock_file
        return released(1) unless phase_one_passed?(config)

        launch_slow_suite(config)
        progress.slow_launched
        released(fast_passed?(config) ? 0 : 1)
      end

      private

      def recorder = @seams.recorder
      def progress = ProgressReporter.new(stdout: @io.stdout)
      def stage_runner = StageRunner.new(commit: @commit, stdout: @io.stdout, seams: @seams, dir: @slot.path)

      # This process's part is over; the slow suite may still be running.
      def released(exit_code)
        @slot.release
        recorder.foreground_done
        exit_code
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

      def launch_slow_suite(config)
        job_id = recorder.start_stage("slow", budget: @seams.budgets["slow"])
        launch(db_path: recorder.db_path, pipeline_run_id: recorder.pipeline_run_id, job_id: job_id,
               executor: slow_suite(config, @slot.share))
      end

      # Called with the recorder and job to record the slow suite with, in
      # whichever process runs it; the slot is let go once it is recorded.
      def slow_suite(config, slot)
        execution = StageExecution.new(seams: @seams, dir: slot.path)
        command = "#{config.script_path("slow")} #{@commit.sha}"
        ->(recorder, job_id) { holding(slot) { execution.run("slow", command, recorder, job_id) } }
      end

      def holding(slot)
        yield
      ensure
        slot.release
      end

      def launch(**)
        return @seams.background_launcher.call(**) if @seams.background_launcher

        @seams = @seams.with(recorder: BackgroundFork.new(recorder, @slot).launch(**))
      end
    end
  end
end
