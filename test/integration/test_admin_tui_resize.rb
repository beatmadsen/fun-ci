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

  CLEAR_SCREEN = "\e[2J"

  def setup
    setup_test_db
    @output = StringIO.new
    @width = 80
    create_completed_run("abc1234", "main")
  end

  def teardown
    teardown_test_db
  end

  def test_should_render_header_at_new_width_after_resize
    tui = build_tui
    tui.resize(120)
    header = fresh_header(tui)
    assert_equal 120, header.length, "Header should be 120 chars wide but was #{header.length}"
  end

  def test_should_use_width_provider_on_each_render
    tui = build_tui(width_provider: -> { @width })
    tui.render_once
    @width = 120
    header = fresh_header(tui)
    assert_equal 120, header.length, "Header should be 120 chars wide but was #{header.length}"
  end

  def test_should_keep_previous_width_when_provider_returns_nil
    tui = build_tui(width_provider: -> { @width })
    tui.render_once
    @width = nil
    header = fresh_header(tui)
    assert_equal 80, header.length, "Header should keep previous width (80) but was #{header.length}"
  end

  def test_should_clear_screen_when_width_changes_between_renders
    tui = build_tui(width_provider: -> { @width })
    tui.render_once
    @width = 120
    tui.render_once
    assert_includes @output.string, CLEAR_SCREEN, "Should emit clear-screen sequence when width changes"
  end

  def test_should_not_clear_screen_when_width_stays_the_same
    tui = build_tui(width_provider: -> { @width })
    tui.render_once
    clear_output
    tui.render_once
    refute_includes @output.string, CLEAR_SCREEN, "Should not clear screen when width unchanged"
  end

  private

  def build_tui(**)
    FunCi::Tui::AdminTui.new(db: @db, output: @output, input: StringIO.new(""), width: 80, **)
  end

  def fresh_header(tui)
    clear_output
    tui.render_once
    FunCi::Tui::Ansi.strip(@output.string).lines.first.chomp
  end

  def clear_output
    @output.truncate(0)
    @output.rewind
  end
end
