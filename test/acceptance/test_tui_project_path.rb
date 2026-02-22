# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/admin_tui"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "fun_ci/tui/ansi"
require "fun_ci/persistence/pipeline_recorder"
require "fun_ci/pipeline/trigger"
require "tmpdir"
require "stringio"

# Acceptance test for Feature 1: Show project path in Console TUI.
#
# The shared database holds pipeline runs from multiple projects.
# The TUI must display which project each commit belongs to so the
# user can distinguish runs at a glance.
#
# ATDD outer loop: this test stays RED until the feature is complete.
# Inner BDD cycles drive the implementation.

class TestTuiProjectPath < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers
  include FunCiTestProject

  def setup
    setup_test_db
    @output = StringIO.new
  end

  def teardown
    teardown_test_db
  end

  def test_should_display_project_name_for_each_pipeline_run
    # Given two pipeline runs from different projects
    create_completed_run_with_project("abc1234", "main", "/home/user/alpha-app")
    create_completed_run_with_project("def5678", "main", "/home/user/beta-service")

    tui = FunCi::Tui::AdminTui.new(db: @db, output: @output, input: StringIO.new(""), width: 120)
    # When the TUI renders
    tui.render_once

    # Then each row should show the project name (basename of the path)
    visible = FunCi::Tui::Ansi.strip(@output.string)
    assert_match(/alpha-app/, visible, "Should display project name 'alpha-app'")
    assert_match(/beta-service/, visible, "Should display project name 'beta-service'")
  end

  def test_should_store_project_path_when_trigger_runs_pipeline
    # Given a project directory with .fun-ci scripts
    project_dir = Dir.mktmpdir("gamma-lib")
    make_project_with_scripts(project_dir)
    recorder = FunCi::Persistence::DbRecorder.new(@db)
    trigger = FunCi::Pipeline::Trigger.new(
      project_root: project_dir,
      commit_hash: "fff9999", branch: "main",
      stdout: StringIO.new, stderr: StringIO.new,
      command_runner: ->(_cmd) { ["", FakeStatus.new(true, 0)] },
      commit_validator: ->(_h) { true },
      recorder: recorder,
      background_launcher: ->(db_path:, pipeline_run_id:, job_id:, executor:) { nil }
    )

    # When the trigger runs
    trigger.run

    # Then the project_path should be stored in the DB
    run = FunCi::Persistence::PipelineRun.find_by_commit(@db, "fff9999").first
    assert_equal project_dir, run[:project_path],
      "Trigger should pass project_root to recorder as project_path"
  ensure
    FileUtils.remove_entry(project_dir) rescue nil
  end

  private

  def create_completed_run_with_project(commit, branch, project_path)
    run_id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: commit, branch: branch, project_path: project_path)
    FunCi::Persistence::PipelineRun.update_status(@db, run_id, "running")
    FunCi::Persistence::PipelineRun.update_status(@db, run_id, "completed")
    %w[lint build fast slow].each do |stage|
      job_id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: run_id, stage: stage)
      FunCi::Persistence::StageJob.update_status(@db, job_id, "running")
      FunCi::Persistence::StageJob.update_status(@db, job_id, "completed")
    end
    run_id
  end
end
