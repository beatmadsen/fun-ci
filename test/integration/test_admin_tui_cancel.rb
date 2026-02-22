# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/admin_tui"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "fun_ci/tui/ansi"
require "tmpdir"
require "stringio"

class TestAdminTuiCancelConfirmation < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
    @output = StringIO.new
  end

  def teardown
    teardown_test_db
  end

  def test_should_show_confirmation_prompt_when_c_pressed_on_running_pipeline
    # Given a running pipeline and the cursor on it
    create_running_run("abc1234", "main")
    tui = make_tui
    tui.handle_key("j") # move cursor to the running row

    # When the user presses "c" to cancel
    tui.handle_key("c")
    tui.render_once
    plain = FunCi::Tui::Ansi.strip(@output.string)

    # Then the footer should show the confirmation prompt
    assert_match(/cancel.*\?.*y\/n/i, plain,
      "Footer should show confirmation prompt with y/n")
    # And the normal key bindings should NOT be visible
    refute_match(/j\/k move/, plain,
      "Normal key bindings should be hidden during confirmation")
  end

  def test_should_return_to_normal_footer_after_confirming_with_y
    # Given a running pipeline in confirmation mode
    create_running_run("abc1234", "main")
    tui = make_tui
    tui.handle_key("j")
    tui.handle_key("c")

    # When the user confirms with "y"
    tui.handle_key("y")
    @output.truncate(0)
    @output.rewind
    tui.render_once
    plain = FunCi::Tui::Ansi.strip(@output.string)

    # Then the footer should return to normal controls
    refute_match(/cancel.*\?.*y\/n/i, plain,
      "Confirmation prompt should be gone after confirming")
  end

  def test_should_return_to_normal_footer_after_declining_with_n
    # Given a running pipeline in confirmation mode
    create_running_run("abc1234", "main")
    tui = make_tui
    tui.handle_key("j")
    tui.handle_key("c")

    # When the user declines with "n"
    tui.handle_key("n")
    @output.truncate(0)
    @output.rewind
    tui.render_once
    plain = FunCi::Tui::Ansi.strip(@output.string)

    # Then the footer should return to normal controls
    assert_match(/j\/k move/, plain,
      "Normal key bindings should return after declining cancel")
    refute_match(/cancel.*\?.*y\/n/i, plain,
      "Confirmation prompt should be gone after declining")
  end

  private

  def make_tui
    FunCi::Tui::AdminTui.new(db: @db, output: @output, input: StringIO.new(""))
  end

  def create_running_run(commit, branch)
    run_id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: commit, branch: branch)
    FunCi::Persistence::PipelineRun.update_status(@db, run_id, "running")
    job_id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: run_id, stage: "build")
    FunCi::Persistence::StageJob.update_status(@db, job_id, "running")
    run_id
  end
end
