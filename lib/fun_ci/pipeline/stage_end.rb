# frozen_string_literal: true

module FunCi
  module Pipeline
    # Records a stage that has finished, whichever process ran it: a failed
    # stage's evidence first, so whoever sees the outcome can read why, then
    # how it exited, then the outcome.
    class StageEnd
      # What running a stage answered: its output, its Process::Status (nil
      # when it was killed over budget) and the failures it reported.
      Finished = Data.define(:output, :status, :timed_out, :failures)

      def initialize(recorder, job_id)
        @recorder = recorder
        @job_id = job_id
      end

      # Answers the outcome recorded: completed, failed or timed_out.
      def record(finished)
        result = outcome(finished)
        keep_evidence(finished) unless result == "completed"
        keep_exit(finished.status) if finished.status
        @recorder.end_stage(@job_id, result)
        result
      end

      private

      def outcome(finished)
        return "timed_out" if finished.timed_out

        finished.status.success? ? "completed" : "failed"
      end

      def keep_evidence(finished)
        @recorder.keep_output(@job_id, finished.output)
        @recorder.keep_failures(@job_id, finished.failures)
      end

      def keep_exit(status)
        signal = status.termsig && Signal.signame(status.termsig)
        @recorder.keep_exit(@job_id, status.exitstatus, signal)
      end
    end
  end
end
