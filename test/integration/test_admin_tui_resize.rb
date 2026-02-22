# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/admin_tui"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "fun_ci/tui/ansi"
require "tmpdir"
require "stringio"

class TestAdminTuiResize < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
    @output = StringIO.new
  end

  def teardown
    teardown_test_db
  end

  def test_should_render_header_at_new_width_after_resize
    # Given a TUI at width 80 with a completed run
    create_completed_run("abc1234", "main")
    tui = FunCi::Tui::AdminTui.new(db: @db, output: @output, input: StringIO.new(""), width: 80)
    # When resize is called with new width
    tui.resize(120)
    @output.truncate(0)
    @output.rewind
    tui.render_once
    plain = FunCi::Tui::Ansi.strip(@output.string)
    header = plain.lines.first.chomp
    # Then header should fill 120 columns
    assert_equal 120, header.length,
      "Header should be 120 chars wide but was #{header.length}"
  end

  def test_should_use_width_provider_on_each_render
    # Given a TUI with a width_provider returning 80
    create_completed_run("abc1234", "main")
    current_width = 80
    width_provider = -> { current_width }
    tui = FunCi::Tui::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      width: 80, width_provider: width_provider
    )
    tui.render_once
    # When width_provider returns 120 on next render
    current_width = 120
    @output.truncate(0)
    @output.rewind
    tui.render_once
    plain = FunCi::Tui::Ansi.strip(@output.string)
    header = plain.lines.first.chomp
    # Then header should fill 120 columns
    assert_equal 120, header.length,
      "Header should be 120 chars wide but was #{header.length}"
  end

  def test_should_keep_previous_width_when_provider_returns_nil
    # Given a TUI with a width_provider returning 80
    create_completed_run("abc1234", "main")
    current_width = 80
    width_provider = -> { current_width }
    tui = FunCi::Tui::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      width: 80, width_provider: width_provider
    )
    tui.render_once
    # When width_provider returns nil
    current_width = nil
    @output.truncate(0)
    @output.rewind
    tui.render_once
    plain = FunCi::Tui::Ansi.strip(@output.string)
    header = plain.lines.first.chomp
    # Then header should still fill 80 columns (previous width)
    assert_equal 80, header.length,
      "Header should keep previous width (80) but was #{header.length}"
  end

  def test_should_clear_screen_when_width_changes_between_renders
    # Given a TUI with a width_provider returning 80
    create_completed_run("abc1234", "main")
    current_width = 80
    width_provider = -> { current_width }
    tui = FunCi::Tui::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      width: 80, width_provider: width_provider
    )
    tui.render_once

    # When width_provider returns 120 on next render (without truncating output)
    current_width = 120
    tui.render_once

    # Then the output should contain a clear-screen sequence (ESC[2J)
    assert_includes @output.string, "\e[2J",
      "Should emit clear-screen sequence when width changes"
  end

  def test_should_not_clear_screen_when_width_stays_the_same
    # Given a TUI with a width_provider returning 80
    create_completed_run("abc1234", "main")
    current_width = 80
    width_provider = -> { current_width }
    tui = FunCi::Tui::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      width: 80, width_provider: width_provider
    )
    tui.render_once
    @output.truncate(0)
    @output.rewind

    # When width_provider returns the same width on next render
    tui.render_once

    # Then no clear-screen sequence should be emitted
    refute_includes @output.string, "\e[2J",
      "Should not clear screen when width unchanged"
  end

end
