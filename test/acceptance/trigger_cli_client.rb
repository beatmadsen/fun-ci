# frozen_string_literal: true

require "stringio"
require "tmpdir"
require "fileutils"
require "fun_ci/trigger"
require "fun_ci/database"
require "fun_ci/pipeline_recorder"
require "fun_ci/pipeline_run"

# Acceptance test client for the Trigger CLI.
#
# Hides implementation details behind an intent-revealing API.
# Tests call this client instead of invoking the CLI or service directly.
# This isolates the tests from internal API changes and makes them read
# like user scenarios.
#
# Pattern: see knowledge.md Section 13 "The Client Abstraction Pattern"

class TriggerCliClient
  attr_reader :exit_code, :stdout, :stderr, :db, :project_dir

  def initialize(command_runner: nil, background_launcher: nil)
    @exit_code = nil
    @stdout = ""
    @stderr = ""
    @db_dir = Dir.mktmpdir("fun-ci-test-db")
    @db = FunCi::Database.connection(File.join(@db_dir, "test.sqlite3"))
    FunCi::Database.migrate!(@db)
    @recorder = FunCi::DbRecorder.new(@db)
    @command_runner = command_runner
    @background_launcher = background_launcher
  end

  def close
    @db.close rescue nil
    FileUtils.remove_entry(@db_dir) rescue nil
    FileUtils.remove_entry(@project_dir) rescue nil if @project_dir
  end

  # Invoke the trigger CLI with a commit hash and branch name.
  # This is the primary entry point -- the action the user takes.
  def trigger(commit_hash:, branch:, scripts: {}, time_budgets: {}, commit_validator: nil)
    @project_dir ||= Dir.mktmpdir("fun-ci-test")
    fun_ci_dir = File.join(@project_dir, ".fun-ci")
    args_dir = File.join(@project_dir, ".fun-ci-args")
    Dir.mkdir(fun_ci_dir) unless Dir.exist?(fun_ci_dir)
    Dir.mkdir(args_dir) unless Dir.exist?(args_dir)

    # Clear previous run's arg capture files
    Dir.children(args_dir).each { |f| File.delete(File.join(args_dir, f)) }

    %w[lint.sh build.sh fast.sh slow.sh].each do |script|
      args_file = File.join(args_dir, script)
      body = scripts.fetch(script, "exit 0")
      path = File.join(fun_ci_dir, script)
      File.write(path, <<~SH)
        #!/bin/sh
        echo "$@" > #{args_file}
        #{body}
      SH
      File.chmod(0o755, path)
    end
    run_trigger(project_root: @project_dir, commit_hash: commit_hash, branch: branch, time_budgets: time_budgets, commit_validator: commit_validator)
  end

  # Invoke the trigger CLI with missing or invalid arguments.
  def trigger_raw(args: [])
    stdout_io = StringIO.new
    stderr_io = StringIO.new
    @exit_code = FunCi::Trigger.run_from_args(args, stdout: stdout_io, stderr: stderr_io)
    @stdout = stdout_io.string
    @stderr = stderr_io.string
  end

  # Invoke the trigger CLI against a project that has no .fun-ci/ folder.
  def trigger_without_fun_ci_folder(commit_hash:, branch:)
    Dir.mktmpdir("fun-ci-test") do |dir|
      run_trigger(project_root: dir, commit_hash: commit_hash, branch: branch)
    end
  end

  # Invoke the trigger CLI against a project where a specific hook script
  # is missing from the .fun-ci/ folder.
  # missing_script should be one of: "build.sh", "fast.sh", "slow.sh"
  def trigger_with_missing_script(commit_hash:, branch:, missing_script:)
    Dir.mktmpdir("fun-ci-test") do |dir|
      fun_ci_dir = File.join(dir, ".fun-ci")
      Dir.mkdir(fun_ci_dir)
      # Create all scripts EXCEPT the missing one
      %w[lint.sh build.sh fast.sh slow.sh].each do |script|
        next if script == missing_script
        path = File.join(fun_ci_dir, script)
        File.write(path, "#!/bin/sh\nexit 0\n")
        File.chmod(0o755, path)
      end
      run_trigger(project_root: dir, commit_hash: commit_hash, branch: branch)
    end
  end

  # Invoke the trigger CLI against a project where a specific hook script
  # exists in .fun-ci/ but lacks execute permission.
  def trigger_with_nonexecutable_script(commit_hash:, branch:, script:)
    Dir.mktmpdir("fun-ci-test") do |dir|
      fun_ci_dir = File.join(dir, ".fun-ci")
      Dir.mkdir(fun_ci_dir)
      %w[lint.sh build.sh fast.sh slow.sh].each do |s|
        path = File.join(fun_ci_dir, s)
        File.write(path, "#!/bin/sh\nexit 0\n")
        if s == script
          File.chmod(0o644, path) # not executable
        else
          File.chmod(0o755, path)
        end
      end
      run_trigger(project_root: dir, commit_hash: commit_hash, branch: branch)
    end
  end

  # Query what arguments were passed to a hook script during the last run.
  # Returns an array of arguments the script received, or nil if not invoked.
  # Foreground scripts (build/fast) complete before trigger() returns.
  # Background scripts (slow) must use a synchronous launcher in tests.
  def script_arguments_for(script_name)
    return nil unless @project_dir
    args_file = File.join(@project_dir, ".fun-ci-args", script_name)
    return nil unless File.exist?(args_file) && File.size(args_file) > 0
    File.read(args_file).strip.split(" ")
  end

  def success?
    @exit_code == 0
  end

  def failed?
    !success?
  end

  # Query the most recent pipeline run from the database for a commit.
  def pipeline_runs_for(commit_hash:)
    FunCi::PipelineRun.find_by_commit(@db, commit_hash)
  end

  def store_pid_for_run(run_id, pid)
    FunCi::PipelineRun.store_pid(@db, run_id, pid)
  end

  # Query stage jobs for a given pipeline run ID.
  def stage_jobs_for(pipeline_run_id:)
    rows = @db.execute(
      "SELECT id, pipeline_run_id, stage, status, started_at, completed_at FROM stage_jobs WHERE pipeline_run_id = ? ORDER BY id",
      [pipeline_run_id]
    )
    rows.map { |r| { id: r[0], pipeline_run_id: r[1], stage: r[2], status: r[3], started_at: r[4], completed_at: r[5] } }
  end

  private

  def noop_launcher(db_path:, pipeline_run_id:, job_id:, executor:) = nil

  def run_trigger(project_root:, commit_hash:, branch:, time_budgets: {}, commit_validator: nil)
    stdout_io = StringIO.new
    stderr_io = StringIO.new
    # Default to always-valid in test contexts (tmpdir has no git repo)
    validator = commit_validator || ->(_hash) { true }
    opts = {
      project_root: project_root,
      commit_hash: commit_hash,
      branch: branch,
      stdout: stdout_io,
      stderr: stderr_io,
      time_budgets: time_budgets,
      commit_validator: validator,
      recorder: @recorder,
      command_runner: @command_runner
    }
    opts[:background_launcher] = @background_launcher || method(:noop_launcher)
    trigger = FunCi::Trigger.new(**opts)
    @exit_code = trigger.run
    @stdout = stdout_io.string
    @stderr = stderr_io.string
  end
end
