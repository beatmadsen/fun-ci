# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/agent/snapshots"
require_relative "../support/fake_git"

# A look at the project's recent runs, for telling what happened since the last.
class TestAgentSnapshots < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
    @snapshots = FunCi::Agent::Snapshots.new(@db, FakeGit.new("/project"))
  end

  def teardown = teardown_test_db

  def test_should_list_the_finished_stages_in_the_order_they_finished
    run = new_run("abc1234")
    create_stage_job(run, "build", "running", "failed")
    create_stage_job(run, "lint", "running", "completed")
    create_stage_job(run, "fast", "running")

    assert_equal([%w[build failed], %w[lint passed]], take.fetch(run).finished.map do |stage|
      stage.values_at(:stage, :state)
    end)
  end

  def test_should_name_the_commit_that_superseded_a_cancelled_run
    run = new_run("abc1234")
    FunCi::Persistence::PipelineRun.update_status(@db, run, "cancelled")
    new_run("bcd2345")

    assert_equal "bcd2345", take.fetch(run).superseded_by
  end

  def test_should_name_no_newer_commit_for_a_run_that_was_not_superseded
    run = new_run("abc1234")
    new_run("bcd2345")

    assert_nil take.fetch(run).superseded_by
  end

  def test_should_look_only_at_the_project_s_newest_runs
    new_run("abc1234", project: "/elsewhere")
    3.times { |n| new_run("run#{n}") }

    assert_equal %w[run2 run1], take(limit: 2).values.map(&:sha)
  end

  private

  def take(limit: 10) = @snapshots.take(limit: limit)

  def new_run(sha, project: "/project")
    FunCi::Persistence::PipelineRun.create(@db, commit_hash: sha, branch: "main", project_path: project)
  end
end
