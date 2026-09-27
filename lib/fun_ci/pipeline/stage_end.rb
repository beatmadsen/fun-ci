# frozen_string_literal: true

module FunCi
  module Pipeline
    # Records a stage that has finished, whichever process ran it: a failed
    # stage's evidence first, so whoever sees the outcome can read why, then
    # how it exited, then the outcome. Called while the stage still holds its
    # slot and report directory, which the collector reads.
    class StageEnd
      # What running a stage answered: its output, and its Process::Status
      # (nil when it was killed over budget).
      Finished = Data.define(:output, :status, :timed_out)

      def initialize(recorder, job_id, collector)
        @recorder = recorder
        @job_id = job_id
        @collector = collector
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
        alongside = @recorder.alongside(@job_id)
        @recorder.keep_evidence(@job_id, @collector.collect(finished.output, alongside: alongside))
        @recorder.keep_raw(@job_id, @collector.masked(finished.output))
      end

      def keep_exit(status)
        signal = status.termsig && Signal.signame(status.termsig)
        @recorder.keep_exit(@job_id, status.exitstatus, signal)
      end
    end
  end
end
