# frozen_string_literal: true

require "stringio"
require "fun_ci/agent/commands"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "fun_ci/persistence/trunk_checks"
require_relative "trigger_workspace"
require_relative "../support/fake_git"
require_relative "../support/fake_clock"
require_relative "../support/fake_pipeline"

# Acceptance test client for the commands an agent runs in a project: tests
# record runs as the pipeline would and read what the agent sees.
class AgentClient
  Fakes = Data.define(:git, :clock, :pipeline)
  Outcome = Data.define(:stdout, :exit_code)

  def self.open = new(TriggerWorkspace.create)

  def initialize(workspace)
    @workspace = workspace
    @fakes = Fakes.new(git: FakeGit.new(workspace.project_dir), clock: FakeClock.new, pipeline: FakePipeline.new)
  end

  def close = @workspace.close
  def db = @workspace.db
  def git = @fakes.git
  def clock = @fakes.clock
  def pipeline = @fakes.pipeline
  def stdout = @outcome.stdout
  def exit_code = @outcome.exit_code

  def status(*args) = agent("status", args)
  def runs(*args) = agent("runs", args)
  def wait(*args) = agent("wait", args)
  def events(*args) = agent("events", args)
  def why(*args) = agent("why", args)

  # stages: { "lint" => "completed", "fast" => "running", ... }, in the order they started.
  def record_run(sha, branch: "main", project: @workspace.project_dir, stages: {})
    run_id = FunCi::Persistence::PipelineRun.create(db, commit_hash: sha, branch: branch, project_path: project)
    FunCi::Persistence::PipelineRun.update_status(db, run_id, "running")
    stages.each { |stage, state| record_stage(run_id, stage, state) }
    run_id
  end

  # A check of the commit against the trunk, as the pipeline would record it.
  def record_trunk_check(sha, trunk_sha:, seen:, outcome:, **counts)
    check = FunCi::Trunk::Check.new(commit: sha, ref: "origin/main", trunk_sha: trunk_sha, seen_at: seen,
                                    outcome: outcome, **counts)
    FunCi::Persistence::TrunkChecks.new(db, @workspace.project_dir).record(check, checked_at: clock.now)
  end

  # A stage of a recorded run finishing now, as the pipeline would record it.
  def finish_stage(run_id, stage, state) = record_stage(run_id, stage, state)

  private

  def record_stage(run_id, stage, state)
    job_id = FunCi::Persistence::StageJob.create(db, pipeline_run_id: run_id, stage: stage)
    FunCi::Persistence::StageJob.update_status(db, job_id, "running")
    FunCi::Persistence::StageJob.update_status(db, job_id, state) unless state == "running"
  end

  def agent(command, args)
    out = StringIO.new
    context = FunCi::Agent::Context.new(db: db, git: git, io: FunCi::Pipeline::Io.new(stdout: out, stderr: out),
                                        clock: clock, pipeline: pipeline)
    code = FunCi::Agent::Commands.run(command, args, context)
    @outcome = Outcome.new(stdout: out.string, exit_code: code)
    code
  end
end
