# frozen_string_literal: true

require "stringio"
require "tmpdir"
require "fileutils"
require "fun_ci/pipeline/trigger"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_recorder"
require "fun_ci/persistence/pipeline_run"
require_relative "scripted_project"
require_relative "trigger_workspace"
require_relative "../support/trigger_test_kit"

# Acceptance test client for the Trigger CLI: tests say what the user does
# and what they see, and this client knows how the Trigger is wired.
class TriggerCliClient
  def self.open(command_runner: nil, background_launcher: nil)
    new(TriggerWorkspace.create, command_runner: command_runner, background_launcher: background_launcher)
  end

  def initialize(workspace, command_runner: nil, background_launcher: nil)
    @workspace = workspace
    @seams = { command_runner: command_runner, background_launcher: background_launcher || ->(**) {},
               recorder: FunCi::Persistence::DbRecorder.new(workspace.db) }
  end

  def close = @workspace.close
  def db = @workspace.db
  def project_dir = @workspace.project_dir
  def exit_code = @outcome.exit_code
  def stdout = @outcome.stdout
  def stderr = @outcome.stderr

  # The action the user takes: commit (or push) on a branch.
  def trigger(commit_hash:, branch:, scripts: {}, commit_validator: nil)
    ScriptedProject.new(project_dir).write(scripts)
    run_trigger(project_dir, FunCi::Pipeline::Commit.new(sha: commit_hash, branch: branch), commit_validator)
  end

  # Invoke the trigger CLI with missing or invalid arguments.
  def trigger_raw(args: [])
    io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: StringIO.new)
    capture(FunCi::Pipeline::Trigger.run_from_args(args, io: io), io)
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

  # The slow suite needs a synchronous launcher for these two.
  def ran?(script_name) = ScriptedProject.new(project_dir).ran?(script_name)
  def script_arguments_for(script_name) = ScriptedProject.new(project_dir).arguments_for(script_name)

  def success? = exit_code.zero?
  def failed? = !success?
  def pipeline_runs_for(commit_hash:) = FunCi::Persistence::PipelineRun.find_by_commit(db, commit_hash)
  def store_pid_for_run(run_id, pid) = FunCi::Persistence::PipelineRun.store_pid(db, run_id, pid)

  STAGE_JOB_COLUMNS = %i[id pipeline_run_id stage status started_at completed_at].freeze

  def stage_jobs_for(pipeline_run_id:)
    rows = db.execute("SELECT #{STAGE_JOB_COLUMNS.join(", ")} FROM stage_jobs WHERE pipeline_run_id = ? ORDER BY id",
                      [pipeline_run_id])
    rows.map { |row| STAGE_JOB_COLUMNS.zip(row).to_h }
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
    capture(FunCi::Pipeline::Trigger.new(project: project_dir, commit: commit, io: io, seams: seams).run, io)
  end

  def capture(exit_code, io)
    @outcome = TriggerTestKit::Outcome.new(exit_code, io.stdout.string, io.stderr.string)
  end
end
