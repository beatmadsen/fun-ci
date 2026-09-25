# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/admin_tui"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "fun_ci/tui/ansi"
require "tmpdir"
require "stringio"

# Acceptance test for TUI resize behavior.
#
# Verifies the user-visible behavior: after a terminal resize,
# the TUI produces a CLEAN frame with NO ghost content from the
# previous width.
class TestTuiResizeCleanFrame < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  NEW_WIDTH = 120

  def setup
    setup_test_db
    @output = StringIO.new
    @width = 80
  end

  def teardown
    teardown_test_db
  end

  def test_should_show_exactly_one_header_after_resize
    header_count = visible_lines_after_resize.count { |l| l.include?("fun-ci") }
    assert_equal 1, header_count,
                 "Should have exactly one header in visible frame, got #{header_count}"
  end

  def test_should_fill_new_width_with_header_after_resize
    header = visible_lines_after_resize.first
    assert_equal NEW_WIDTH, header.length,
                 "Header should fill 120 columns but was #{header.length}"
  end

  def test_should_leave_no_line_wider_than_new_width_after_resize
    too_wide = visible_lines_after_resize.select { |l| l.length > NEW_WIDTH }
    assert_empty too_wide,
                 "No lines should exceed 120 columns: #{too_wide.inspect}"
  end

  def test_should_render_complete_frame_with_footer_after_resize
    assert visible_lines_after_resize.any? { |l| l.include?("q quit") },
           "Visible frame should contain footer"
  end

  private

  def visible_lines_after_resize
    create_completed_run("abc1234", "main")
    tui = FunCi::Tui::AdminTui.new(db: @db, output: @output, input: StringIO.new(""),
                                   width: @width, width_provider: -> { @width })
    tui.render_once
    @width = NEW_WIDTH
    tui.render_once
    FunCi::Tui::Ansi.strip(visible_frame(@output.string)).lines.map(&:chomp)
  end

  # On a real terminal, \e[2J clears the screen, so only what follows the last clear is visible.
  def visible_frame(raw)
    raw.split("\e[2J").last || raw
  end
end
