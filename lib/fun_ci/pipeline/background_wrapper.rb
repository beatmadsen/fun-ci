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

      # Keeps a failed suite's output and reported failures before recording
      # its outcome, as StageRunner does. The executor answers
      # [output, status, timed_out, failures reported].
      def run
        output, status, timed_out, failures = @executor.call { |pid| @recorder.stage_process(@job_id, pid) }
        result = OUTCOMES.fetch(outcome(status, timed_out))
        keep_evidence(output, failures || []) unless result == "completed"
        @recorder.end_stage(@job_id, result)
      end

      private

      def keep_evidence(output, failures)
        @recorder.keep_output(@job_id, output)
        @recorder.keep_failures(@job_id, failures)
      end

      def outcome(status, timed_out)
        return :timed_out if timed_out

        status.success? ? :passed : :failed
      end
    end
  end
end
