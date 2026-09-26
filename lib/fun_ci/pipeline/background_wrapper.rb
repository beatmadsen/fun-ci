# frozen_string_literal: true

module FunCi
  module Pipeline
    class BackgroundWrapper
      def initialize(recorder:, job_id:, executor:)
        @recorder = recorder
        @job_id = job_id
        @executor = executor
      end

      OUTCOMES = { timed_out: "timed_out", passed: "completed", failed: "failed" }.freeze

      def run
        _output, status, timed_out = @executor.call { |pid| @recorder.stage_process(@job_id, pid) }
        @recorder.end_stage(@job_id, OUTCOMES.fetch(outcome(status, timed_out)))
      end

      private

      def outcome(status, timed_out)
        return :timed_out if timed_out

        status.success? ? :passed : :failed
      end
    end
  end
end
