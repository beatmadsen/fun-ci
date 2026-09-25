# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/animation_renderer"
require "fun_ci/tui/screen"
require "fun_ci/tui/ansi"
require "stringio"

class TestAnimationRendererHeaderPlayer < Minitest::Test
  include AnimationRendererTestHelpers

  WRITE_AT = /\e\[\d+;\d+H/
  EVENT_LINE = /line-one/

  def test_should_trigger_multi_line_header_on_failure
    frame = render_after_transition(make_run(1, "running", fast: "running"), make_run(1, "failed", fast: "failed"))
    assert frame.scan(WRITE_AT).length > 1, "Should write multiple screen positions for multi-line header"
    assert_match EVENT_LINE, frame, "Should show the failure animation in the header"
  end

  def test_should_trigger_multi_line_header_on_success
    frame = render_after_transition(make_run(1, "running", slow: "running"),
                                    make_run(1, "completed", slow: "completed"))
    assert frame.scan(WRITE_AT).length > 1, "Should write multiple screen positions for multi-line header"
    assert_match EVENT_LINE, frame, "Should show the success animation in the header"
  end

  def test_should_expire_header_player_after_all_frames
    renderer, screen, = make_renderer_and_screen
    failed = make_run(1, "failed", fast: "failed")
    render_all(renderer, screen, [make_run(1, "running", fast: "running"), failed])
    60.times { renderer.render(screen, [failed]) if renderer.any_active? }
    refute renderer.any_active?, "All animations should expire after enough renders"
  end

  def test_should_not_trigger_header_player_on_timeout
    renderer, screen, output = make_renderer_and_screen
    timed_out = make_run(1, "failed", fast: "timed_out")
    render_all(renderer, screen, [make_run(1, "running", fast: "running")] + ([timed_out] * 6))
    refute renderer.any_active?, "Timeout should not leave a long-running header event"
    refute_match EVENT_LINE, output.string, "Timeout should not show an event animation in the header"
  end

  def test_should_not_trigger_header_player_on_stage_pass
    renderer, screen, output = make_renderer_and_screen
    lint_passed = make_run(1, "running", lint: "completed")
    render_all(renderer, screen, [make_run(1, "running", lint: "running")] + ([lint_passed] * 6))
    refute renderer.any_active?, "stage_pass should not trigger long-running header player"
    refute_match EVENT_LINE, output.string, "stage_pass should not show an event animation in the header"
  end

  private

  def render_after_transition(from_run, to_run)
    renderer, screen, output = make_renderer_and_screen
    render_all(renderer, screen, [from_run, to_run])
    output.truncate(0)
    output.rewind
    renderer.render(screen, [to_run])
    output.string
  end

  def render_all(renderer, screen, runs)
    runs.each { |run| renderer.render(screen, [run]) }
  end
end
