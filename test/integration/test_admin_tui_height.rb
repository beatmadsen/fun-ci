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
    assert_equal 2, rendered_commit_count(runs: 10, height_provider: -> { 20 }),
                 "Terminal height 20 should show 2 rows"
  end

  def test_should_show_all_rows_when_terminal_is_tall_enough
    assert_equal 3, rendered_commit_count(runs: 3, height_provider: -> { 50 }),
                 "Tall terminal should show all 3 rows"
  end

  def test_should_show_zero_rows_when_terminal_shorter_than_header
    assert_equal 0, rendered_commit_count(runs: 3, height_provider: -> { 10 }),
                 "Terminal shorter than header should show 0 rows rather than overflow"
  end

  # Height 17: (17 - 14 - 2) / 2 = 0 rows.
  def test_should_show_zero_rows_at_one_below_minimum_viable_height
    assert_equal 0, rendered_commit_count(runs: 3, height_provider: -> { 17 }),
                 "Height 17 is one line short for 1 row with 14-line header"
  end

  # Height 18: (18 - 14 - 2) / 2 = 1 row.
  # Budget: header(14) + board(1) + post-board separator(1) + footer(1) = 17 lines.
  def test_should_show_one_row_at_minimum_viable_height
    assert_equal 1, rendered_commit_count(runs: 3, height_provider: -> { 18 }),
                 "Height 18 is the minimum for 1 row with 14-line header"
  end

  def test_should_show_all_rows_without_height_provider
    assert_equal 3, rendered_commit_count(runs: 3, height_provider: nil),
                 "Without height_provider, all rows should be visible"
  end

  # Without a clear, the old taller frame stays on screen and the header scrolls off.
  def test_should_clear_screen_when_height_shrinks_between_renders
    current_height = 40
    tui = tui_with_runs(5, height_provider: -> { current_height })
    tui.render_once
    current_height = 20
    tui.render_once
    assert_includes @output.string, "\e[2J",
                    "Should emit clear-screen when height shrinks to prevent header from scrolling off"
  end

  # IO.console is nil when there is no controlling terminal.
  def test_should_show_all_rows_when_height_provider_returns_nil
    assert_equal 3, rendered_commit_count(runs: 3, height_provider: -> {}),
                 "Nil height should not truncate rows"
  end

  private

  def tui_with_runs(count, height_provider:)
    count.times { |i| create_completed_run("hash#{format("%03d", i)}", "main") }
    FunCi::Tui::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      width: 120, height_provider: height_provider
    )
  end

  def rendered_commit_count(runs:, height_provider:)
    tui_with_runs(runs, height_provider: height_provider).render_once
    plain = FunCi::Tui::Ansi.strip(@output.string)
    plain.lines.count { |l| l.match?(/hash\d+/) }
  end
end
