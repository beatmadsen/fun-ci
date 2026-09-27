# frozen_string_literal: true

require_relative "stage_end"
require_relative "../evidence/collector"

module FunCi
  module Pipeline
    # Runs a stage that has been started, in `dir`, with a report directory of
    # its own, and records how it ended while it still holds both. The same
    # for every stage, the slow suite in its forked child included.
    class StageExecution
      def initialize(seams:, dir:)
        @seams = seams
        @dir = dir
      end

      # Answers [the outcome recorded, what the stage printed].
      def run(stage, command, recorder, job_id)
        with_report_dir do |reports|
          output, status, timed_out = execute(stage, command, reports.env) { |pid| recorder.stage_process(job_id, pid) }
          finished = StageEnd::Finished.new(output: output, status: status, timed_out: timed_out)
          [StageEnd.new(recorder, job_id, collector(stage, reports)).record(finished), output]
        end
      end

      private

      def execute(stage, command, env, &) = @seams.executor(@dir).call(command, @seams.budgets[stage], env: env, &)

      def with_report_dir
        reports = @seams.report_dir.call
        yield reports
      ensure
        reports&.remove
      end

      def collector(stage, reports)
        Evidence::Collector.new(Evidence::Sources.new(stage: stage, worktree: @dir, reports: reports,
                                                      environment: @seams.environment.merge(reports.env)))
      end
    end
  end
end
