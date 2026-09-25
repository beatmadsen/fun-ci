# frozen_string_literal: true

require_relative "../test_helper"
require_relative "trigger_cli_client"
require "fun_ci/pipeline/background_wrapper"

# Instant command runner — returns success without spawning any OS process.
# Use for tests that don't care about real script execution.
INSTANT_SUCCESS_RUNNER = ->(_cmd) { ["", FakeStatus.new(true, 0)] }

# A command runner that simulates script execution: writes args to file + returns success/failure.
# Use for tests that assert on ran? or script_arguments_for (which read the args file).
# Derives project_dir from the command path: /project/.fun-ci/script.sh -> /project
def script_simulating_runner(failures: {})
  lambda { |cmd|
    script_path, *args = cmd.split
    record_script_args(script_path, args)
    simulated_script_result(failures[File.basename(script_path)])
  }
end

def record_script_args(script_path, args)
  args_dir = File.join(File.dirname(script_path, 2), ".fun-ci-args")
  FileUtils.mkdir_p(args_dir)
  File.write(File.join(args_dir, File.basename(script_path)), args.join(" "))
end

def simulated_script_result(failure)
  return ["", FakeStatus.new(true, 0)] unless failure

  [failure[:output] || "", FakeStatus.new(false, failure[:exit] || 1)]
end

# A command runner where the named script exits 1 and every other script succeeds.
def failing_script_runner(script_name)
  ->(cmd) { cmd.include?(script_name) ? ["", FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)] }
end

# A command runner where the named script blows its time budget and every other script succeeds.
def timing_out_script_runner(script_name)
  lambda { |cmd|
    raise Timeout::Error, "budget exceeded" if cmd.include?(script_name)

    ["", FakeStatus.new(true, 0)]
  }
end

# Synchronous launcher for deterministic slow-suite testing.
# Runs BackgroundWrapper inline instead of forking, so the test
# can inspect database state immediately after trigger() returns.
SYNC_LAUNCHER = lambda { |db_path:, pipeline_run_id:, job_id:, executor:|
  recorder = FunCi::Persistence::DbRecorder.for_background(db_path, pipeline_run_id)
  FunCi::Pipeline::BackgroundWrapper.new(recorder: recorder, job_id: job_id, executor: executor).run
  recorder.close
}
