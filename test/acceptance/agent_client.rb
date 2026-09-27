# frozen_string_literal: true

require "stringio"
require "fun_ci/agent/commands"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require_relative "trigger_workspace"
require_relative "../support/fake_git"

# Acceptance test client for the commands an agent runs in a project: tests
# record runs as the pipeline would and read what the agent sees.
class AgentClient
  attr_reader :git, :exit_code

  def self.open = new(TriggerWorkspace.create)

  def initialize(workspace)
    @workspace = workspace
    @git = FakeGit.new(workspace.project_dir)
  end

  def close = @workspace.close
  def db = @workspace.db
  def stdout = @out.string

  def status(*args) = agent("status", args)

  # stages: { "lint" => "completed", "fast" => "running", ... }, in the order they started.
  def record_run(sha, branch: "main", project: @workspace.project_dir, stages: {})
    run_id = FunCi::Persistence::PipelineRun.create(db, commit_hash: sha, branch: branch, project_path: project)
    FunCi::Persistence::PipelineRun.update_status(db, run_id, "running")
    stages.each { |stage, state| record_stage(run_id, stage, state) }
    run_id
  end

  private

  def record_stage(run_id, stage, state)
    job_id = FunCi::Persistence::StageJob.create(db, pipeline_run_id: run_id, stage: stage)
    FunCi::Persistence::StageJob.update_status(db, job_id, "running")
    FunCi::Persistence::StageJob.update_status(db, job_id, state) unless state == "running"
  end

  def agent(command, args)
    @out = StringIO.new
    io = FunCi::Pipeline::Io.new(stdout: @out, stderr: @out)
    @exit_code = FunCi::Agent::Commands.run(command, args, FunCi::Agent::Context.new(db: db, git: @git, io: io))
  end
end
