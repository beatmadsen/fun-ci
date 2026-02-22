# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/admin_tui"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "fun_ci/tui/ansi"
require "tmpdir"
require "stringio"

class TestAdminTuiHeight < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
    @output = StringIO.new
  end

  def teardown
    teardown_test_db
  end

  def test_should_truncate_rows_to_fit_terminal_height
    # Given 10 pipeline runs and a short terminal
    10.times { |i| create_completed_run("hash#{format("%03d", i)}", "main") }
    tui = make_tui(height_provider: -> { 20 })

    # When the TUI renders
    tui.render_once

    # Then fewer rows than available should be visible
    assert_equal 2, rendered_commit_count,
      "Terminal height 20 should show 2 rows"
  end

  def test_should_show_all_rows_when_terminal_is_tall_enough
    # Given 3 pipeline runs and a tall terminal
    3.times { |i| create_completed_run("hash#{format("%03d", i)}", "main") }
    tui = make_tui(height_provider: -> { 50 })

    # When the TUI renders
    tui.render_once

    # Then all 3 rows should be visible
    assert_equal 3, rendered_commit_count,
      "Tall terminal should show all 3 rows"
  end

  def test_should_show_zero_rows_when_terminal_shorter_than_header
    # Given pipeline runs and a terminal shorter than the header + chrome
    3.times { |i| create_completed_run("hash#{format("%03d", i)}", "main") }
    tui = make_tui(height_provider: -> { 10 })

    # When the TUI renders
    tui.render_once

    # Then no rows should be shown (header alone exceeds terminal height)
    assert_equal 0, rendered_commit_count,
      "Terminal shorter than header should show 0 rows rather than overflow"
  end

  def test_should_show_one_row_at_minimum_viable_height
    # Given pipeline runs and a terminal just tall enough for header + 1 row + footer
    # HEADER_HEIGHT(14) + 2*1-1(board) + 1(blank) + 1(footer) = 17
    3.times { |i| create_completed_run("hash#{format("%03d", i)}", "main") }
    tui = make_tui(height_provider: -> { 17 })

    # When the TUI renders
    tui.render_once

    # Then exactly 1 row should be visible
    assert_equal 1, rendered_commit_count,
      "Height 17 is the minimum for 1 row with 14-line header"
  end

  def test_should_never_render_more_lines_than_terminal_height
    # Given pipeline runs and a terminal just below the 1-row minimum
    3.times { |i| create_completed_run("hash#{format("%03d", i)}", "main") }
    tui = make_tui(height_provider: -> { 16 })

    # When the TUI renders
    tui.render_once

    # Then total output lines must not exceed terminal height
    println_count = @output.string.scan(/\r\n/).length
    assert println_count <= 16,
      "Output must not exceed terminal height (got #{println_count} lines for height 16)"
  end

  def test_should_show_all_rows_without_height_provider
    # Given pipeline runs and no height_provider (backward compatibility)
    3.times { |i| create_completed_run("hash#{format("%03d", i)}", "main") }
    tui = make_tui

    # When the TUI renders
    tui.render_once

    # Then all rows should be visible (no truncation)
    assert_equal 3, rendered_commit_count,
      "Without height_provider, all rows should be visible"
  end

  def test_should_clear_screen_when_height_shrinks_between_renders
    # Given pipeline runs and a terminal that shrinks between renders
    5.times { |i| create_completed_run("hash#{format("%03d", i)}", "main") }
    current_height = 40
    height_provider = -> { current_height }
    tui = make_tui(height_provider: height_provider)
    tui.render_once

    # When the terminal height shrinks (e.g. splitting a tmux pane)
    current_height = 20
    tui.render_once

    # Then a clear-screen sequence should be emitted to prevent stale content
    # (Without clear, the old taller frame stays on screen and the header scrolls off)
    assert_includes @output.string, "\e[2J",
      "Should emit clear-screen when height shrinks to prevent header from scrolling off"
  end

  def test_should_show_all_rows_when_height_provider_returns_nil
    # Given pipeline runs and a height_provider that returns nil
    # (e.g. IO.console is nil when there is no controlling terminal)
    3.times { |i| create_completed_run("hash#{format("%03d", i)}", "main") }
    tui = make_tui(height_provider: -> { nil })

    # When the TUI renders
    tui.render_once

    # Then all rows should be visible (nil treated as unknown)
    assert_equal 3, rendered_commit_count,
      "Nil height should not truncate rows"
  end

  private

  def make_tui(height_provider: nil)
    FunCi::Tui::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      width: 120, height_provider: height_provider
    )
  end

  def rendered_commit_count
    plain = FunCi::Tui::Ansi.strip(@output.string)
    plain.lines.count { |l| l.match?(/hash\d+/) }
  end
end
