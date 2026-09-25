# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/admin_tui"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "fun_ci/tui/ansi"
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

  CHARCOAL_BACKGROUND = /\e\[48;5;236m/
  BOARD_START_ROW = FunCi::Tui::HeaderAnimationManager::HEADER_HEIGHT + 1

  # Draws its own header overlay, as the real animation renderer does.
  class HeaderOverlayRenderer
    def render(screen, _runs)
      14.times { |i| screen.write_at(1 + i, 1, "anim-line-#{i}") }
    end
  end

  def test_should_skip_header_println_when_animation_renderer_is_present
    rendered = render_frame(animation_renderer: HeaderOverlayRenderer.new)
    refute_match(CHARCOAL_BACKGROUND, rendered,
                 "Header bar (charcoal background) should not be rendered when animation renderer is active")
  end

  def test_should_position_cursor_at_board_start_when_animation_renderer_is_present
    rendered = render_frame(animation_renderer: HeaderOverlayRenderer.new)
    assert_match(/\e\[#{BOARD_START_ROW};1H/, rendered,
                 "Board should be positioned at row #{BOARD_START_ROW} via write_at")
  end

  def test_should_still_render_header_via_println_without_animation_renderer
    rendered = render_frame
    assert_match(CHARCOAL_BACKGROUND, rendered, "Header bar should be rendered via println when no animation renderer")
    refute_match(/\e\[#{BOARD_START_ROW};1H/, rendered,
                 "Should not use write_at cursor positioning without animation renderer")
  end

  private

  def render_frame(animation_renderer: nil)
    create_completed_run("abc1234", "main")
    FunCi::Tui::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      width: 120, animation_renderer: animation_renderer
    ).render_once
    @output.string
  end
end
