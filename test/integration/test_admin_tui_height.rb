# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/admin_tui"
require "fun_ci/database"
require "fun_ci/pipeline_run"
require "fun_ci/stage_job"
require "fun_ci/ansi"
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

  def test_should_show_at_least_one_row_even_in_very_short_terminal
    # Given pipeline runs and a terminal shorter than the header chrome
    3.times { |i| create_completed_run("hash#{format("%03d", i)}", "main") }
    tui = make_tui(height_provider: -> { 10 })

    # When the TUI renders
    tui.render_once

    # Then at least 1 row should be visible (never zero)
    assert_equal 1, rendered_commit_count,
      "Very short terminal should still show 1 row"
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
    FunCi::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      width: 120, height_provider: height_provider
    )
  end

  def rendered_commit_count
    plain = FunCi::Ansi.strip(@output.string)
    plain.lines.count { |l| l.match?(/hash\d+/) }
  end
end
