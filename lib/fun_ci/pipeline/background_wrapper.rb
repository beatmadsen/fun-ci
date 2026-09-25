# frozen_string_literal: true

module FunCi
  module Pipeline
    class BackgroundWrapper
      def initialize(recorder:, job_id:, executor:)
        @recorder = recorder
        @job_id = job_id
        @executor = executor
      end

      OUTCOMES = {
        timed_out: ["timed_out", :fail_run],
        passed: ["completed", :complete_run],
        failed: ["failed", :fail_run]
      }.freeze

      def run
        _output, status, timed_out = @executor.call { |pid| @recorder.stage_process(@job_id, pid) }
        stage_status, run_action = OUTCOMES.fetch(outcome(status, timed_out))
        @recorder.end_stage(@job_id, stage_status)
        @recorder.public_send(run_action)
      end

      private

      def outcome(status, timed_out)
        return :timed_out if timed_out

        status.success? ? :passed : :failed
      end
    end
  end
end
