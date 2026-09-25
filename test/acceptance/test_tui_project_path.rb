# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/admin_tui"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "fun_ci/tui/ansi"
require "fun_ci/persistence/pipeline_recorder"
require_relative "../support/trigger_test_kit"
require "tmpdir"
require "stringio"

# Acceptance test for Feature 1: Show project path in Console TUI.
#
# The shared database holds pipeline runs from multiple projects.
# The TUI must display which project each commit belongs to so the
# user can distinguish runs at a glance.
#
class TestTuiProjectPath < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers
  include FunCiTestProject
  include TriggerTestKit

  def setup
    setup_test_db
    @output = StringIO.new
  end

  def teardown
    teardown_test_db
  end

  def test_should_display_project_name_for_each_pipeline_run
    create_completed_run_with_project("abc1234", "/home/user/alpha-app")
    create_completed_run_with_project("def5678", "/home/user/beta-service")
    FunCi::Tui::AdminTui.new(db: @db, output: @output, input: StringIO.new(""), width: 120).render_once

    assert_match(/alpha-app.*beta-service|beta-service.*alpha-app/m, FunCi::Tui::Ansi.strip(@output.string))
  end

  def test_should_store_project_path_when_trigger_runs_pipeline
    project_dir = nil
    in_project do |dir|
      project_dir = dir
      build_trigger(dir, sha: "fff9999", command_runner: scripted_runner,
                         recorder: FunCi::Persistence::DbRecorder.new(@db)).run
    end

    assert_equal project_dir, FunCi::Persistence::PipelineRun.find_by_commit(@db, "fff9999").first[:project_path]
  end

  private

  def create_completed_run_with_project(commit, project_path)
    run_id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: commit, branch: "main",
                                                         project_path: project_path)
    %w[running completed].each { |status| FunCi::Persistence::PipelineRun.update_status(@db, run_id, status) }
    %w[lint build fast slow].each { |stage| create_stage_job(run_id, stage, "running", "completed") }
  end
end
