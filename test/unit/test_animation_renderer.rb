# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/animation_renderer"
require "fun_ci/screen"
require "fun_ci/ansi"
require "stringio"

class TestAnimationRendererDetection < Minitest::Test
  include AnimationRendererTestHelpers

  def test_should_have_no_animations_on_first_render
    renderer, screen, = make_renderer_and_screen
    # When we render for the first time (no previous state to compare)
    renderer.render(screen, [make_run(1, "running")])
    # Then no animation should be active
    refute renderer.any_active?, "First render has no previous state to detect changes"
  end

  def test_should_detect_stage_failure
    renderer, screen, = make_renderer_and_screen
    # Given a run with a running stage
    renderer.render(screen, [make_run(1, "running", lint: "running")])
    # When the stage fails on next render
    renderer.render(screen, [make_run(1, "failed", lint: "failed")])
    # Then a failure animation should be active
    assert renderer.any_active?, "Should trigger animation on stage failure"
  end

  def test_should_detect_stage_completion_mid_run
    renderer, screen, = make_renderer_and_screen
    # Given a run with a running stage
    renderer.render(screen, [make_run(1, "running", lint: "running")])
    # When one stage completes while the run continues
    renderer.render(screen, [make_run(1, "running", lint: "completed")])
    # Then a stage_pass animation should be active
    assert renderer.any_active?, "Should trigger animation on stage completion"
  end

  def test_should_detect_pipeline_completion
    renderer, screen, = make_renderer_and_screen
    renderer.render(screen, [make_run(1, "running", slow: "running")])
    # When the whole pipeline completes
    renderer.render(screen, [make_run(1, "completed", slow: "completed")])
    # Then a success animation should be active
    assert renderer.any_active?, "Should trigger animation on pipeline completion"
  end

  def test_should_detect_timeout
    renderer, screen, = make_renderer_and_screen
    renderer.render(screen, [make_run(1, "running", fast: "running")])
    # When a stage times out
    renderer.render(screen, [make_run(1, "failed", fast: "timed_out")])
    # Then a timeout animation should be active
    assert renderer.any_active?, "Should trigger animation on stage timeout"
  end

  def test_should_not_duplicate_animation_on_repeated_same_transition
    renderer, screen, = make_renderer_and_screen
    # Given two runs with running stages that both complete
    renderer.render(screen, [
      make_run(1, "running", lint: "running"),
      make_run(2, "running", lint: "running")
    ])
    renderer.render(screen, [
      make_run(1, "running", lint: "completed"),
      make_run(2, "running", lint: "completed")
    ])

    # When we re-trigger the same transition (same type, run_id, stage)
    # by resetting lint to running and completing again
    renderer.render(screen, [
      make_run(1, "running", lint: "running"),
      make_run(2, "running", lint: "running")
    ])
    renderer.render(screen, [
      make_run(1, "running", lint: "completed"),
      make_run(2, "running", lint: "completed")
    ])

    # Then active count should be 2 (one per run), not 4
    assert_equal 2, renderer.active_count
  end
end

class TestAnimationRendererFrameAdvancement < Minitest::Test
  include AnimationRendererTestHelpers

  def test_should_expire_stage_pass_after_all_frames
    renderer, screen, = make_renderer_and_screen
    renderer.render(screen, [make_run(1, "running", lint: "running")])

    # When we trigger and advance through all stage_pass frames (3 total)
    3.times { renderer.render(screen, [make_run(1, "running", lint: "completed")]) }

    # Then the animation should have expired
    refute renderer.any_active?, "stage_pass should expire after its frames"
  end

  def test_should_expire_failure_after_all_animations_finish
    renderer, screen, = make_renderer_and_screen
    renderer.render(screen, [make_run(1, "running", fast: "running")])
    renderer.render(screen, [make_run(1, "failed", fast: "failed")])

    # When we advance enough renders for both Animation and HeaderAnimationPlayer to finish
    # (advance until no animations remain; failure footers are held 8x so need more renders)
    60.times do
      break unless renderer.any_active?
      renderer.render(screen, [make_run(1, "failed", fast: "failed")])
    end

    # Then all animations should have expired
    refute renderer.any_active?, "All animations should expire eventually"
  end

  def test_should_track_simultaneous_animations
    renderer, screen, = make_renderer_and_screen
    # Given two runs with running stages
    renderer.render(screen, [
      make_run(1, "running", lint: "running"),
      make_run(2, "running", build: "running")
    ])
    # When both complete in the same render
    renderer.render(screen, [
      make_run(1, "running", lint: "completed"),
      make_run(2, "running", build: "completed")
    ])
    # Then both should be counted as active
    assert_equal 2, renderer.active_count
  end
end
