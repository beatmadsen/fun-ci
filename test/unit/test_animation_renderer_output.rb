# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/animation_renderer"
require "fun_ci/tui/screen"
require "fun_ci/tui/ansi"
require "stringio"

class TestAnimationRendererOverlayOutput < Minitest::Test
  include AnimationRendererTestHelpers

  # The footer holds 8 blank frames; the trigger render is frame 0, so frame 9 shows footer content.
  FRAMES_BEFORE_FOOTER = 8

  def test_should_render_header_player_content_on_failure
    raw = last_render_output(fast_running, fast_failed)
    assert_match(/line-one/, FunCi::Tui::Ansi.strip(raw), "Should render header player frame content")
  end

  def test_should_write_multi_line_header_on_success
    raw = last_render_output(slow_running, slow_completed, slow_completed)
    write_at_rows = raw.scan(/\e\[(\d+);\d+H/).map { |m| m[0].to_i }.uniq
    assert write_at_rows.length > 1, "Should write to multiple rows for multi-line header"
  end

  def test_should_bracket_overlays_with_save_and_restore_cursor
    raw = last_render_output(fast_running, fast_failed)
    save_pos = raw.index("\e[s")
    restore_pos = raw.index("\e[u")
    assert save_pos, "Should contain save_cursor"
    assert restore_pos, "Should contain restore_cursor"
    assert save_pos < restore_pos, "Save should come before restore"
  end

  def test_should_show_stage_name_in_failure_footer
    raw = last_render_output(fast_running, *[fast_failed] * (FRAMES_BEFORE_FOOTER + 1))
    assert_match(/FAST FAILED/, FunCi::Tui::Ansi.strip(raw), "Footer should show which stage failed")
  end

  def test_should_render_background_overlay_when_no_event_animations
    lint_completed = make_run(1, "completed", lint: "completed")
    raw = last_render_output(lint_completed, lint_completed)
    assert_match(/\e\[s/, raw, "Should save cursor for background overlay")
    assert_match(/idle-/, FunCi::Tui::Ansi.strip(raw), "Should render idle animation content")
    refute @renderer.any_active?, "No event animations should be active"
  end

  def test_should_show_nice_in_success_footer
    raw = last_render_output(slow_running, *[slow_completed] * (FRAMES_BEFORE_FOOTER + 1))
    assert_match(/NICE!/, FunCi::Tui::Ansi.strip(raw), "Success footer should celebrate")
  end

  private

  # Renders each run in turn and returns only what the final render wrote.
  def last_render_output(*runs)
    @renderer, screen, output = make_renderer_and_screen
    runs[0..-2].each { |run| @renderer.render(screen, [run]) }
    output.truncate(0)
    output.rewind
    @renderer.render(screen, [runs.last])
    output.string
  end

  def fast_running = make_run(1, "running", fast: "running")
  def fast_failed = make_run(1, "failed", fast: "failed")
  def slow_running = make_run(1, "running", slow: "running")
  def slow_completed = make_run(1, "completed", slow: "completed")
end
