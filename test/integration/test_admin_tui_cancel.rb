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

  CONFIRMATION_PROMPT = %r{cancel.*\?.*y / n}i
  NORMAL_BINDINGS = %r{j/k move}

  def setup
    setup_test_db
    @output = StringIO.new
  end

  def teardown
    teardown_test_db
  end

  def test_should_show_confirmation_prompt_when_c_pressed_on_running_pipeline
    plain = screen_after_keys("j", "c")
    assert_match(CONFIRMATION_PROMPT, plain, "Footer should show confirmation prompt with y/n")
    refute_match(NORMAL_BINDINGS, plain, "Normal key bindings should be hidden during confirmation")
  end

  def test_should_return_to_normal_footer_after_confirming_with_y
    plain = screen_after_keys("j", "c", "y")
    refute_match(CONFIRMATION_PROMPT, plain, "Confirmation prompt should be gone after confirming")
  end

  def test_should_return_to_normal_footer_after_declining_with_n
    plain = screen_after_keys("j", "c", "n")
    assert_match(NORMAL_BINDINGS, plain, "Normal key bindings should return after declining cancel")
    refute_match(CONFIRMATION_PROMPT, plain, "Confirmation prompt should be gone after declining")
  end

  private

  # Renders once after the keys, with the cursor starting above the one running pipeline.
  def screen_after_keys(*keys)
    create_running_run("abc1234", "main")
    tui = FunCi::Tui::AdminTui.new(db: @db, output: @output, input: StringIO.new(""))
    keys.each { |key| tui.handle_key(key) }
    @output.truncate(0)
    @output.rewind
    tui.render_once
    FunCi::Tui::Ansi.strip(@output.string)
  end

  def create_running_run(commit, branch)
    run_id = FunCi::Persistence::PipelineRun.create(@db, commit_hash: commit, branch: branch)
    FunCi::Persistence::PipelineRun.update_status(@db, run_id, "running")
    job_id = FunCi::Persistence::StageJob.create(@db, pipeline_run_id: run_id, stage: "build")
    FunCi::Persistence::StageJob.update_status(@db, job_id, "running")
    run_id
  end
end
