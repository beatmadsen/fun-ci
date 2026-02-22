# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/animation_renderer"
require "fun_ci/screen"
require "fun_ci/ansi"
require "stringio"

class TestAnimationRendererOverlayOutput < Minitest::Test
  include AnimationRendererTestHelpers

  def test_should_render_header_player_content_on_failure
    renderer, screen, output = make_renderer_and_screen
    # Given a failure transition triggers the header player
    renderer.render(screen, [make_run(1, "running", fast: "running")])
    output.truncate(0)
    output.rewind

    # When the failure is detected
    renderer.render(screen, [make_run(1, "failed", fast: "failed")])

    # Then the output should contain the header player's frame content
    plain = FunCi::Ansi.strip(output.string)
    assert_match(/line-one/, plain, "Should render header player frame content")
  end

  def test_should_write_multi_line_header_on_success
    renderer, screen, output = make_renderer_and_screen
    # Given a success animation triggered
    renderer.render(screen, [make_run(1, "running", slow: "running")])
    renderer.render(screen, [make_run(1, "completed", slow: "completed")])

    # When we capture the next render
    output.truncate(0)
    output.rewind
    renderer.render(screen, [make_run(1, "completed", slow: "completed")])

    # Then it should write to multiple rows via write_at
    raw = output.string
    write_at_rows = raw.scan(/\e\[(\d+);\d+H/).map { |m| m[0].to_i }.uniq
    assert write_at_rows.length > 1, "Should write to multiple rows for multi-line header"
  end

  def test_should_bracket_overlays_with_save_and_restore_cursor
    renderer, screen, output = make_renderer_and_screen
    # Given a transition that triggers an animation
    renderer.render(screen, [make_run(1, "running", fast: "running")])
    output.truncate(0)
    output.rewind

    # When the animation triggers
    renderer.render(screen, [make_run(1, "failed", fast: "failed")])

    # Then save should come before restore in the output
    raw = output.string
    save_pos = raw.index("\e[s")
    restore_pos = raw.index("\e[u")
    assert save_pos, "Should contain save_cursor"
    assert restore_pos, "Should contain restore_cursor"
    assert save_pos < restore_pos, "Save should come before restore"
  end

  def test_should_show_stage_name_in_failure_footer
    renderer, screen, output = make_renderer_and_screen
    # Given a failure animation triggered on the fast stage
    renderer.render(screen, [make_run(1, "running", fast: "running")])
    renderer.render(screen, [make_run(1, "failed", fast: "failed")])

    # Advance past the FOOTER_HOLD nil frames (8 nils at start)
    # Trigger render was frame 0, so we need 8 more renders to reach frame 8
    7.times { renderer.render(screen, [make_run(1, "failed", fast: "failed")]) }

    # When we capture the render at frame 9 (footer content visible at index 8+)
    output.truncate(0)
    output.rewind
    renderer.render(screen, [make_run(1, "failed", fast: "failed")])

    # Then the footer should identify the failed stage
    plain = FunCi::Ansi.strip(output.string)
    assert_match(/FAST FAILED/, plain, "Footer should show which stage failed")
  end

  def test_should_render_idle_overlay_when_no_event_animations
    renderer, screen, output = make_renderer_and_screen
    # Given an initial render (no prior state)
    renderer.render(screen, [make_run(1, "running", lint: "running")])
    output.truncate(0)
    output.rewind

    # When we render the same state (no transition)
    renderer.render(screen, [make_run(1, "running", lint: "running")])

    # Then idle animation should still render (save/restore cursor always present)
    assert_match(/\e\[s/, output.string, "Should save cursor for idle overlay")
    plain = FunCi::Ansi.strip(output.string)
    assert_match(/idle-/, plain, "Should render idle animation content")
    refute renderer.any_active?, "No event animations should be active"
  end

  def test_should_show_nice_in_success_footer
    renderer, screen, output = make_renderer_and_screen
    # Given a success animation triggered
    renderer.render(screen, [make_run(1, "running", slow: "running")])
    renderer.render(screen, [make_run(1, "completed", slow: "completed")])

    # Advance past the FOOTER_HOLD nil frames (8 nils at start)
    7.times { renderer.render(screen, [make_run(1, "completed", slow: "completed")]) }

    # When we capture the render at frame 9 (footer content visible at index 8+)
    output.truncate(0)
    output.rewind
    renderer.render(screen, [make_run(1, "completed", slow: "completed")])

    # Then the footer should contain NICE!
    plain = FunCi::Ansi.strip(output.string)
    assert_match(/NICE!/, plain, "Success footer should celebrate")
  end
end
