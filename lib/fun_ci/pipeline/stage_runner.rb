# frozen_string_literal: true

require_relative "trigger_params"
require_relative "stage_execution"

module FunCi
  module Pipeline
    class StageRunner
      LABELS = { "lint" => "Lint", "build" => "Build", "fast" => "Fast suite", "slow" => "Slow suite" }.freeze
      ADVICE = {
        "lint" => "Trim your linter config or split into stages.",
        "build" => "Keep your build efficient and not let it become a bottleneck.",
        "fast" => "Your fast tests have gotten too slow. Split or speed them up.",
        "slow" => "Pare down integration tests, parallelise, or raise the budget."
      }.freeze
      FIX_TESTS = "Fix the failing tests above, then try again."
      NEXT_STEPS = {
        "lint" => "Fix what the linter reported above, then try again.",
        "build" => "Fix the build errors above, then try again.",
        "fast" => FIX_TESTS,
        "slow" => FIX_TESTS
      }.freeze

      def initialize(commit:, stdout:, seams: Seams.new, dir: Dir.pwd)
        @commit = commit
        @stdout = stdout
        @seams = seams
        @dir = dir
      end

      # A failed stage's evidence is kept before its outcome is recorded, so
      # whoever sees the outcome can read why.
      def passes?(config, stage)
        job_id = @seams.recorder.start_stage(stage, budget: @seams.budgets[stage])
        command = "#{config.script_path(stage)} #{@commit.sha}"
        result, output = StageExecution.new(seams: @seams, dir: @dir).run(stage, command, @seams.recorder, job_id)
        tell(stage, output, result)
        result == "completed"
      end

      private

      def tell(stage, output, result)
        report_timeout(stage) if result == "timed_out"
        report_failure(stage, output) if result == "failed"
      end

      def report_timeout(stage)
        @stdout.puts "#{label(stage)} killed -- exceeded #{@seams.budgets[stage]}s time budget."
        @stdout.puts ADVICE[stage]
      end

      def report_failure(stage, output)
        @stdout.puts output unless output.empty?
        @stdout.puts "#{label(stage)} failed."
        @stdout.puts NEXT_STEPS[stage]
      end

      def label(stage) = LABELS.fetch(stage, stage)
    end
  end
end
