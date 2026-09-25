# frozen_string_literal: true

require_relative "trigger_params"

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

      def initialize(commit_hash:, stdout:, seams: Seams.new)
        @commit_hash = commit_hash
        @stdout = stdout
        @seams = seams
      end

      def passes?(config, stage)
        job_id = @seams.recorder.start_stage(stage)
        status = outcome(stage, *execute(config, stage))
        @seams.recorder.end_stage(job_id, status)
        status == "completed"
      end

      private

      def execute(config, stage)
        @seams.executor.call("#{config.script_path(stage)} #{@commit_hash}", @seams.budgets[stage])
      end

      def outcome(stage, output, status, timed_out)
        return report_timeout(stage) if timed_out
        return report_failure(stage, output) unless status.success?

        "completed"
      end

      def report_timeout(stage)
        @stdout.puts "#{label(stage)} killed -- exceeded #{@seams.budgets[stage]}s time budget."
        @stdout.puts ADVICE[stage]
        "timed_out"
      end

      def report_failure(stage, output)
        @stdout.puts output unless output.empty?
        @stdout.puts "#{label(stage)} failed."
        "failed"
      end

      def label(stage) = LABELS.fetch(stage, stage)
    end
  end
end
