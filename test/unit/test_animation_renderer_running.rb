# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/animation_renderer"
require "fun_ci/screen"
require "fun_ci/ansi"
require "stringio"

class TestAnimationRendererRunningState < Minitest::Test
  include AnimationRendererTestHelpers

  def test_should_show_running_animation_when_pipeline_is_running
    renderer, screen, output = make_renderer_and_screen
    # Given a first render to establish state
    renderer.render(screen, [make_run(1, "pending")])
    output.truncate(0)
    output.rewind

    # When a run transitions to running
    renderer.render(screen, [make_run(1, "running", lint: "running")])
    output.truncate(0)
    output.rewind

    # Then subsequent renders should show running animation content
    renderer.render(screen, [make_run(1, "running", lint: "running")])
    plain = FunCi::Ansi.strip(output.string)
    assert_match(/running-/, plain, "Should show running animation in header")
  end

  def test_should_show_idle_when_no_pipeline_running
    renderer, screen, output = make_renderer_and_screen
    # Given only completed runs
    renderer.render(screen, [make_run(1, "completed", lint: "completed")])
    output.truncate(0)
    output.rewind

    # When we render with no running pipelines
    renderer.render(screen, [make_run(1, "completed", lint: "completed")])

    # Then idle animation should be shown
    plain = FunCi::Ansi.strip(output.string)
    assert_match(/idle-/, plain, "Should show idle when nothing is running")
  end

  def test_should_stop_running_animation_when_pipeline_completes
    renderer, screen, output = make_renderer_and_screen
    # Given a running pipeline
    renderer.render(screen, [make_run(1, "running", lint: "running")])
    renderer.render(screen, [make_run(1, "running", lint: "running")])

    # When the pipeline completes (and event animations expire)
    renderer.render(screen, [make_run(1, "completed", slow: "completed")])
    60.times do
      break unless renderer.any_active?
      renderer.render(screen, [make_run(1, "completed", slow: "completed")])
    end

    output.truncate(0)
    output.rewind
    renderer.render(screen, [make_run(1, "completed", slow: "completed")])

    # Then idle should be back (not running)
    plain = FunCi::Ansi.strip(output.string)
    assert_match(/idle-/, plain, "Should return to idle after pipeline completes")
    refute_match(/running-/, plain, "Should not show running content")
  end

  def test_should_show_running_when_any_pipeline_is_running
    renderer, screen, output = make_renderer_and_screen
    # Given one completed and one running pipeline
    renderer.render(screen, [
      make_run(1, "completed", lint: "completed"),
      make_run(2, "running", lint: "running")
    ])
    output.truncate(0)
    output.rewind

    # When we render again (no transitions, steady state)
    renderer.render(screen, [
      make_run(1, "completed", lint: "completed"),
      make_run(2, "running", lint: "running")
    ])

    # Then running animation should show (because run 2 is running)
    plain = FunCi::Ansi.strip(output.string)
    assert_match(/running-/, plain, "Should show running when any pipeline is active")
  end
end
