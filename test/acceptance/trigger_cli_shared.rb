# frozen_string_literal: true

require_relative "../test_helper"
require_relative "trigger_cli_client"
require "fun_ci/background_wrapper"

# Synchronous launcher for deterministic slow-suite testing.
# Runs BackgroundWrapper inline instead of forking, so the test
# can inspect database state immediately after trigger() returns.
SYNC_LAUNCHER = ->(db_path:, pipeline_run_id:, job_id:, executor:) {
  recorder = FunCi::DbRecorder.for_background(db_path, pipeline_run_id)
  FunCi::BackgroundWrapper.new(recorder: recorder, job_id: job_id, executor: executor).run
  recorder.close
}
