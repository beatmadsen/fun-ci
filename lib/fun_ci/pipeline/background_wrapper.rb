# frozen_string_literal: true

require_relative "stage_end"

module FunCi
  module Pipeline
    # Runs the slow suite in the forked child and records it as StageRunner
    # records the other stages.
    class BackgroundWrapper
      def initialize(recorder:, job_id:, executor:)
        @recorder = recorder
        @job_id = job_id
        @executor = executor
      end

      # The executor answers [output, status, timed_out, failures reported].
      def run
        output, status, timed_out, failures = @executor.call { |pid| @recorder.stage_process(@job_id, pid) }
        finished = StageEnd::Finished.new(output: output, status: status, timed_out: timed_out,
                                          failures: failures || [])
        StageEnd.new(@recorder, @job_id).record(finished)
      end
    end
  end
end
