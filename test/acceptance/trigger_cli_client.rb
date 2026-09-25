# frozen_string_literal: true

require "stringio"
require "tmpdir"
require "fileutils"
require "fun_ci/pipeline/trigger"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_recorder"
require "fun_ci/persistence/pipeline_run"
require_relative "scripted_project"

# Acceptance test client for the Trigger CLI: tests say what the user does
# and what they see, and this client knows how the Trigger is wired.
class TriggerCliClient
  attr_reader :exit_code, :stdout, :stderr, :db, :project_dir

  def initialize(command_runner: nil, background_launcher: nil)
    @db_dir = Dir.mktmpdir("fun-ci-test-db")
    @db = FunCi::Persistence::Database.connection(File.join(@db_dir, "test.sqlite3"))
    FunCi::Persistence::Database.migrate!(@db)
    @seams = { command_runner: command_runner, background_launcher: background_launcher || ->(**) {},
               recorder: FunCi::Persistence::DbRecorder.new(@db) }
  end

  def close
    @db.close
    [@db_dir, @project_dir].compact.each { |dir| FileUtils.rm_rf(dir) }
  end

  # The action the user takes: commit (or push) on a branch.
  def trigger(commit_hash:, branch:, scripts: {}, commit_validator: nil)
    @project_dir ||= Dir.mktmpdir("fun-ci-test")
    ScriptedProject.new(@project_dir).write(scripts)
    run_trigger(@project_dir, FunCi::Pipeline::Commit.new(sha: commit_hash, branch: branch), commit_validator)
  end

  # Invoke the trigger CLI with missing or invalid arguments.
  def trigger_raw(args: [])
    io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: StringIO.new)
    @exit_code = FunCi::Pipeline::Trigger.run_from_args(args, io: io)
    capture(io)
  end

  def trigger_without_fun_ci_folder(commit_hash:, branch:)
    in_other_project(commit_hash, branch) { |_project| nil }
  end

  # missing_script is one of the four stage scripts, e.g. "build.sh".
  def trigger_with_missing_script(commit_hash:, branch:, missing_script:)
    in_other_project(commit_hash, branch) { |project| project.write.then { project.remove(missing_script) } }
  end

  def trigger_with_nonexecutable_script(commit_hash:, branch:, script:)
    in_other_project(commit_hash, branch) { |project| project.write.then { project.chmod(script, 0o644) } }
  end

  # The arguments a stage script received in the last run, or nil if it was
  # not invoked. The slow suite needs a synchronous launcher for this.
  def script_arguments_for(script_name)
    @project_dir && ScriptedProject.new(@project_dir).arguments_for(script_name)
  end

  def success? = @exit_code.zero?
  def failed? = !success?
  def pipeline_runs_for(commit_hash:) = FunCi::Persistence::PipelineRun.find_by_commit(@db, commit_hash)
  def store_pid_for_run(run_id, pid) = FunCi::Persistence::PipelineRun.store_pid(@db, run_id, pid)

  def stage_jobs_for(pipeline_run_id:)
    @db.execute("SELECT id, pipeline_run_id, stage, status, started_at, completed_at FROM stage_jobs " \
                "WHERE pipeline_run_id = ? ORDER BY id", [pipeline_run_id])
       .map { |row| %i[id pipeline_run_id stage status started_at completed_at].zip(row).to_h }
  end

  private

  def in_other_project(commit_hash, branch)
    Dir.mktmpdir("fun-ci-test") do |dir|
      yield ScriptedProject.new(dir)
      run_trigger(dir, FunCi::Pipeline::Commit.new(sha: commit_hash, branch: branch))
    end
  end

  # A temp dir is no git repository, so commits are valid unless a test says otherwise.
  def run_trigger(project_dir, commit, commit_validator = nil)
    io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: StringIO.new)
    seams = FunCi::Pipeline::Seams.new(**@seams, commit_validator: commit_validator || ->(_sha) { true })
    @exit_code = FunCi::Pipeline::Trigger.new(project: project_dir, commit: commit, io: io, seams: seams).run
    capture(io)
  end

  def capture(io)
    @stdout = io.stdout.string
    @stderr = io.stderr.string
  end
end
