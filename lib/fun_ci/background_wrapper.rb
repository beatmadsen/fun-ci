# frozen_string_literal: true

require "timeout"

module FunCi
  class BackgroundWrapper
    def initialize(recorder:, job_id:, executor:)
      @recorder = recorder
      @job_id = job_id
      @executor = executor
    end

    def run
      _output, status = @executor.call
      if status.success?
        @recorder.end_stage(@job_id, "completed")
        @recorder.complete_run
      else
        @recorder.end_stage(@job_id, "failed")
        @recorder.fail_run
      end
    rescue Timeout::Error
      @recorder.end_stage(@job_id, "timed_out")
      @recorder.fail_run
    end
  end
end
