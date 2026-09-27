# frozen_string_literal: true

require_relative "trigger_params"
require_relative "stage_end"

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

      def initialize(commit_hash:, stdout:, seams: Seams.new, dir: Dir.pwd)
        @commit_hash = commit_hash
        @stdout = stdout
        @seams = seams
        @dir = dir
      end

      # A failed stage's output and reported failures are kept before its
      # outcome is recorded, so whoever sees the outcome can read why.
      def passes?(config, stage)
        job_id = @seams.recorder.start_stage(stage, budget: @seams.budgets[stage])
        with_report_dir { |reports| run_stage(config, stage, job_id, reports) } == "completed"
      end

      private

      def run_stage(config, stage, job_id, reports)
        output, status, timed_out = execute(config, stage, reports.env) do |pid|
          @seams.recorder.stage_process(job_id, pid)
        end
        finished = StageEnd::Finished.new(output: output, status: status, timed_out: timed_out,
                                          failures: reports.failures)
        StageEnd.new(@seams.recorder, job_id).record(finished).tap { |result| tell(stage, output, result) }
      end

      def with_report_dir
        reports = @seams.report_dir.call
        yield reports
      ensure
        reports&.remove
      end

      def execute(config, stage, env, &)
        @seams.executor(@dir).call("#{config.script_path(stage)} #{@commit_hash}", @seams.budgets[stage], env: env, &)
      end

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
