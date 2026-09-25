# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/admin_tui"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "fun_ci/tui/ansi"
require "tmpdir"
require "stringio"

module AdminTuiBoardRendering
  include DatabaseTestSetup

  def setup
    setup_test_db
    @output = StringIO.new
  end

  def teardown
    teardown_test_db
  end

  def render_board
    FunCi::Tui::AdminTui.new(db: @db, output: @output, input: StringIO.new("q")).render_once
  end

  def rendered_board
    render_board
    FunCi::Tui::Ansi.strip(@output.string)
  end
end

class TestAdminTuiEmptyState < Minitest::Test
  include AdminTuiBoardRendering

  def test_should_show_empty_state_with_no_runs
    plain = rendered_board
    assert_match(/No runs yet\./, plain)
    assert_match(/fun-ci trigger HEAD/, plain)
  end

  def test_should_show_only_quit_in_footer_when_empty
    plain = rendered_board
    assert_match(/q quit/, plain)
    refute_match(%r{j/k move}, plain)
  end

  def test_should_show_header_when_empty
    assert_match(/fun-ci/, rendered_board)
  end

  def test_should_erase_below_frame_after_render_when_empty
    render_board
    assert @output.string.end_with?("\e[J"),
           "render_once should end with ESC[J even when empty"
  end
end

class TestAdminTuiWithRuns < Minitest::Test
  include AdminTuiBoardRendering
  include PipelineTestHelpers

  def test_should_show_pipeline_rows
    create_completed_run("a3f7c01", "main")
    plain = rendered_board
    assert_match(/a3f7c01/, plain)
    assert_match(/main/, plain)
    assert_match(/PASSED/, plain)
  end

  def test_should_show_streak_in_header
    3.times { |i| create_completed_run("hash#{i.to_s.rjust(3, "0")}", "main") }
    assert_match(/3 in a row!/, rendered_board)
  end

  def test_should_show_full_footer_with_runs
    create_completed_run("a3f7c01", "main")
    plain = rendered_board
    assert_match(%r{j/k move}, plain)
    assert_match(/c cancel/, plain)
    assert_match(/q quit/, plain)
  end

  # ESC[J erases from the cursor to the end of the screen, clearing stale lines
  # left by a previous frame of a different height.
  def test_should_erase_below_frame_after_render_to_prevent_stale_content
    create_completed_run("a3f7c01", "main")
    render_board
    assert @output.string.end_with?("\e[J"),
           "render_once should end with ESC[J to erase stale content below the frame"
  end

  def test_should_show_failed_run
    create_failed_run("91de003", "fix/nil-crash")
    assert_match(/FAILED/, rendered_board)
  end

  def test_should_show_multiple_runs_in_order
    create_completed_run("first11", "main")
    create_completed_run("second2", "develop")
    plain = rendered_board
    assert plain.index("second2") < plain.index("first11"), "Most recent run should appear first"
  end
end
