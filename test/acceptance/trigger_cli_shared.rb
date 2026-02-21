# frozen_string_literal: true

require_relative "../test_helper"
require_relative "trigger_cli_client"
require "fun_ci/background_wrapper"

# Instant command runner — returns success without spawning any OS process.
# Use for tests that don't care about real script execution.
INSTANT_SUCCESS_RUNNER = ->(_cmd) { ["", FakeStatus.new(true, 0)] }

# A command runner that simulates script execution: writes args to file + returns success/failure.
# Use for tests that assert on script_arguments_for (which reads the args file).
# Derives project_dir from the command path: /project/.fun-ci/script.sh -> /project
def script_simulating_runner(failures: {})
  ->(cmd) {
    parts = cmd.split(" ")
    script_path = parts.first
    script_name = File.basename(script_path)
    args = parts[1..]

    project_dir = File.dirname(File.dirname(script_path))
    args_dir = File.join(project_dir, ".fun-ci-args")
    FileUtils.mkdir_p(args_dir)
    File.write(File.join(args_dir, script_name), args.join(" "))

    if failures.key?(script_name)
      [failures[script_name][:output] || "", FakeStatus.new(false, failures[script_name][:exit] || 1)]
    else
      ["", FakeStatus.new(true, 0)]
    end
  }
end

# Synchronous launcher for deterministic slow-suite testing.
# Runs BackgroundWrapper inline instead of forking, so the test
# can inspect database state immediately after trigger() returns.
SYNC_LAUNCHER = ->(db_path:, pipeline_run_id:, job_id:, executor:) {
  recorder = FunCi::DbRecorder.for_background(db_path, pipeline_run_id)
  FunCi::BackgroundWrapper.new(recorder: recorder, job_id: job_id, executor: executor).run
  recorder.close
}
