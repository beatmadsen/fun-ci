# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/animation_renderer"
require "fun_ci/tui/screen"
require "fun_ci/tui/ansi"
require "stringio"

class TestAnimationRendererHeaderPlayer < Minitest::Test
  include AnimationRendererTestHelpers

  def test_should_trigger_multi_line_header_on_failure
    renderer, screen, output = make_renderer_and_screen
    # Given a failure transition
    renderer.render(screen, [make_run(1, "running", fast: "running")])
    renderer.render(screen, [make_run(1, "failed", fast: "failed")])

    # When we capture the next render
    output.truncate(0)
    output.rewind
    renderer.render(screen, [make_run(1, "failed", fast: "failed")])

    # Then it should write to multiple screen positions (multi-line header)
    write_at_count = output.string.scan(/\e\[\d+;\d+H/).length
    assert write_at_count > 1, "Should write multiple screen positions for multi-line header"
  end

  def test_should_trigger_multi_line_header_on_success
    renderer, screen, output = make_renderer_and_screen
    # Given a success transition
    renderer.render(screen, [make_run(1, "running", slow: "running")])
    renderer.render(screen, [make_run(1, "completed", slow: "completed")])

    # When we capture the next render
    output.truncate(0)
    output.rewind
    renderer.render(screen, [make_run(1, "completed", slow: "completed")])

    # Then it should write to multiple screen positions
    write_at_count = output.string.scan(/\e\[\d+;\d+H/).length
    assert write_at_count > 1, "Should write multiple screen positions for multi-line header"
  end

  def test_should_expire_header_player_after_all_frames
    renderer, screen, = make_renderer_and_screen
    # Given a failure animation triggered
    renderer.render(screen, [make_run(1, "running", fast: "running")])
    renderer.render(screen, [make_run(1, "failed", fast: "failed")])

    # When we advance enough renders for all animations to finish
    # (failure footers are held 8x so need more renders)
    60.times do
      break unless renderer.any_active?
      renderer.render(screen, [make_run(1, "failed", fast: "failed")])
    end

    # Then all animations should be expired
    refute renderer.any_active?, "All animations should expire after enough renders"
  end

  def test_should_not_trigger_header_player_on_timeout
    renderer, screen, _output = make_renderer_and_screen
    # Given a timeout transition (not failure/success)
    renderer.render(screen, [make_run(1, "running", fast: "running")])
    renderer.render(screen, [make_run(1, "failed", fast: "timed_out")])

    # When we advance enough for the timeout stage animation to finish
    5.times { renderer.render(screen, [make_run(1, "failed", fast: "timed_out")]) }

    # Then only the stage animation should have been active (no event header player)
    # The timeout should NOT trigger a header event -- idle continues
    refute renderer.any_active?, "Timeout should not leave a long-running header event"
  end

  def test_should_not_trigger_header_player_on_stage_pass
    renderer, screen, = make_renderer_and_screen
    # Given a stage completion (not pipeline completion)
    renderer.render(screen, [make_run(1, "running", lint: "running")])
    renderer.render(screen, [make_run(1, "running", lint: "completed")])

    # When we advance past all stage_pass frames
    5.times { renderer.render(screen, [make_run(1, "running", lint: "completed")]) }

    # Then no animation should remain active
    refute renderer.any_active?, "stage_pass should not trigger long-running header player"
  end
end
