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
#
# The outer ATDD loop: this test stays RED until the resize-clear
# behavior is fully implemented. Inner BDD cycles drive the fix.
#
# Structure follows knowledge.md Section 13: ATDD.

class TestTuiResizeCleanFrame < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
    @output = StringIO.new
  end

  def teardown
    teardown_test_db
  end

  def test_should_produce_only_coherent_frame_after_resize
    # Given a TUI rendered at width 80 with a completed pipeline run
    create_completed_run("abc1234", "main")
    current_width = 80
    width_provider = -> { current_width }
    tui = FunCi::Tui::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      width: 80, width_provider: width_provider
    )
    tui.render_once

    # When the terminal is resized to 120 and another frame renders
    current_width = 120
    tui.render_once

    # Then the visible output should be a single coherent frame at width 120
    visible = visible_frame(@output.string)
    plain = FunCi::Tui::Ansi.strip(visible)
    lines = plain.lines.map(&:chomp)

    # Exactly one header (no ghost header from the old frame)
    header_count = lines.count { |l| l.include?("fun-ci") }
    assert_equal 1, header_count,
      "Should have exactly one header in visible frame, got #{header_count}"

    # Header fills new width
    header = lines.first
    assert_equal 120, header.length,
      "Header should fill 120 columns but was #{header.length}"

    # No lines exceed new width (no stale wide content from previous render)
    too_wide = lines.select { |l| l.length > 120 }
    assert_empty too_wide,
      "No lines should exceed 120 columns: #{too_wide.inspect}"

    # Footer is present (complete frame, not a partial render)
    assert lines.any? { |l| l.include?("q quit") },
      "Visible frame should contain footer"
  end

  private

  # Extract the last visible frame from raw terminal output.
  # On a real terminal, \e[2J clears the screen — everything before it
  # is no longer visible. So the "visible frame" is everything after
  # the last clear-screen sequence.
  def visible_frame(raw)
    parts = raw.split("\e[2J")
    parts.last || raw
  end

end
