# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/admin_tui"
require "fun_ci/database"
require "fun_ci/pipeline_run"
require "fun_ci/stage_job"
require "fun_ci/ansi"
require "tmpdir"
require "stringio"

class TestAdminTuiEmptyState < Minitest::Test
  include DatabaseTestSetup

  def setup
    setup_test_db
    @output = StringIO.new
  end

  def teardown
    teardown_test_db
  end

  def test_should_show_empty_state_with_no_runs
    # Given no pipeline runs exist
    tui = FunCi::AdminTui.new(db: @db, output: @output, input: StringIO.new("q"))
    # When we render the board
    tui.render_once
    plain = FunCi::Ansi.strip(@output.string)
    # Then it should show the empty state
    assert_match(/No runs yet\./, plain)
    assert_match(/fun-ci trigger HEAD/, plain)
  end

  def test_should_show_only_quit_in_footer_when_empty
    tui = FunCi::AdminTui.new(db: @db, output: @output, input: StringIO.new("q"))
    tui.render_once
    plain = FunCi::Ansi.strip(@output.string)
    assert_match(/q quit/, plain)
    refute_match(/j\/k move/, plain)
  end

  def test_should_show_header_when_empty
    tui = FunCi::AdminTui.new(db: @db, output: @output, input: StringIO.new("q"))
    tui.render_once
    plain = FunCi::Ansi.strip(@output.string)
    assert_match(/fun-ci/, plain)
  end

  def test_should_erase_below_frame_after_render_when_empty
    # Given no pipeline runs
    tui = FunCi::AdminTui.new(db: @db, output: @output, input: StringIO.new("q"))
    # When we render
    tui.render_once
    # Then the output should end with ESC[J to erase stale content
    assert @output.string.end_with?("\e[J"),
      "render_once should end with ESC[J even when empty"
  end
end

class TestAdminTuiWithRuns < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
    @output = StringIO.new
  end

  def teardown
    teardown_test_db
  end

  def test_should_show_pipeline_rows
    # Given a completed pipeline run
    create_completed_run("a3f7c01", "main")
    tui = FunCi::AdminTui.new(db: @db, output: @output, input: StringIO.new("q"))
    tui.render_once
    plain = FunCi::Ansi.strip(@output.string)
    assert_match(/a3f7c01/, plain)
    assert_match(/main/, plain)
    assert_match(/PASSED/, plain)
  end

  def test_should_show_streak_in_header
    # Given 3 consecutive passed runs
    3.times { |i| create_completed_run("hash#{i.to_s.rjust(3, "0")}", "main") }
    tui = FunCi::AdminTui.new(db: @db, output: @output, input: StringIO.new("q"))
    tui.render_once
    plain = FunCi::Ansi.strip(@output.string)
    assert_match(/3 in a row!/, plain)
  end

  def test_should_show_full_footer_with_runs
    create_completed_run("a3f7c01", "main")
    tui = FunCi::AdminTui.new(db: @db, output: @output, input: StringIO.new("q"))
    tui.render_once
    plain = FunCi::Ansi.strip(@output.string)
    assert_match(/j\/k move/, plain)
    assert_match(/c cancel/, plain)
    assert_match(/q quit/, plain)
  end

  def test_should_erase_below_frame_after_render_to_prevent_stale_content
    # Given a TUI with one pipeline run
    create_completed_run("a3f7c01", "main")
    tui = FunCi::AdminTui.new(db: @db, output: @output, input: StringIO.new("q"))
    # When we render the board
    tui.render_once
    # Then the output should end with ESC[J (erase from cursor to end of screen)
    # so that stale lines from a previous taller/shorter frame are cleared
    assert @output.string.end_with?("\e[J"),
      "render_once should end with ESC[J to erase stale content below the frame"
  end

  def test_should_show_failed_run
    create_failed_run("91de003", "fix/nil-crash")
    tui = FunCi::AdminTui.new(db: @db, output: @output, input: StringIO.new("q"))
    tui.render_once
    plain = FunCi::Ansi.strip(@output.string)
    assert_match(/FAILED/, plain)
  end

  def test_should_show_multiple_runs_in_order
    create_completed_run("first11", "main")
    create_completed_run("second2", "develop")
    tui = FunCi::AdminTui.new(db: @db, output: @output, input: StringIO.new("q"))
    tui.render_once
    plain = FunCi::Ansi.strip(@output.string)
    # Most recent first
    first_pos = plain.index("second2")
    second_pos = plain.index("first11")
    assert first_pos < second_pos, "Most recent run should appear first"
  end

end
