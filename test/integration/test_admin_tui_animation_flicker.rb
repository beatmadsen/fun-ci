# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/admin_tui"
require "fun_ci/database"
require "fun_ci/pipeline_run"
require "fun_ci/stage_job"
require "fun_ci/ansi"
require "tmpdir"
require "stringio"

class TestAdminTuiAnimationFlicker < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
    @output = StringIO.new
  end

  def teardown
    teardown_test_db
  end

  def test_should_skip_header_println_when_animation_renderer_is_present
    # Given a TUI with an animation renderer that draws the header overlay
    create_completed_run("abc1234", "main")
    renderer = make_header_overlay_renderer
    tui = make_tui(animation_renderer: renderer)

    # When we render a frame
    tui.render_once

    # Then the output should NOT contain the charcoal-background header bar
    # that render_header emits -- the animation renderer owns that area.
    raw = @output.string
    refute_match(/\e\[48;5;236m/, raw,
      "Header bar (charcoal background) should not be rendered when animation renderer is active")
  end

  def test_should_position_cursor_at_board_start_when_animation_renderer_is_present
    # Given a TUI with an animation renderer
    create_completed_run("abc1234", "main")
    renderer = make_header_overlay_renderer
    tui = make_tui(animation_renderer: renderer)

    # When we render
    tui.render_once

    # Then the board content should start after the header area,
    # positioned via write_at rather than println padding.
    raw = @output.string
    header_height = FunCi::HeaderAnimationManager::HEADER_HEIGHT
    expected_row = header_height + 1
    assert_match(/\e\[#{expected_row};1H/, raw,
      "Board should be positioned at row #{expected_row} via write_at")
  end

  def test_should_still_render_header_via_println_without_animation_renderer
    # Given a TUI without an animation renderer
    create_completed_run("abc1234", "main")
    tui = make_tui

    # When we render a frame
    tui.render_once

    # Then the output should contain the charcoal-background header bar
    raw = @output.string
    assert_match(/\e\[48;5;236m/, raw,
      "Header bar should be rendered via println when no animation renderer")
    # And there should be no write_at cursor positioning for the board start
    header_height = FunCi::HeaderAnimationManager::HEADER_HEIGHT
    refute_match(/\e\[#{header_height + 1};1H/, raw,
      "Should not use write_at cursor positioning without animation renderer")
  end

  private

  def make_tui(animation_renderer: nil)
    FunCi::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      width: 120, animation_renderer: animation_renderer
    )
  end

  def make_header_overlay_renderer
    Object.new.tap do |r|
      r.define_singleton_method(:render) do |screen, _runs|
        14.times { |i| screen.write_at(1 + i, 1, "anim-line-#{i}") }
      end
    end
  end
end
