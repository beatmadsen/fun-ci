# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/animation_renderer"
require "fun_ci/tui/screen"
require "fun_ci/tui/ansi"
require "stringio"

class TestAnimationRendererDetection < Minitest::Test
  include AnimationRendererTestHelpers

  def test_should_have_no_animations_on_first_render
    renderer, screen, = make_renderer_and_screen
    renderer.render(screen, [make_run(1, "running")])
    refute renderer.any_active?, "First render has no previous state to detect changes"
  end

  def test_should_detect_stage_failure
    renderer, screen, = make_renderer_and_screen
    renderer.render(screen, [make_run(1, "running", lint: "running")])
    renderer.render(screen, [make_run(1, "failed", lint: "failed")])
    assert renderer.any_active?, "Should trigger animation on stage failure"
  end

  def test_should_detect_stage_completion_mid_run
    renderer, screen, = make_renderer_and_screen
    renderer.render(screen, [make_run(1, "running", lint: "running")])
    renderer.render(screen, [make_run(1, "running", lint: "completed")])
    assert renderer.any_active?, "Should trigger animation on stage completion"
  end

  def test_should_detect_pipeline_completion
    renderer, screen, = make_renderer_and_screen
    renderer.render(screen, [make_run(1, "running", slow: "running")])
    renderer.render(screen, [make_run(1, "completed", slow: "completed")])
    assert renderer.any_active?, "Should trigger animation on pipeline completion"
  end

  def test_should_detect_timeout
    renderer, screen, = make_renderer_and_screen
    renderer.render(screen, [make_run(1, "running", fast: "running")])
    renderer.render(screen, [make_run(1, "failed", fast: "timed_out")])
    assert renderer.any_active?, "Should trigger animation on stage timeout"
  end

  def test_should_not_duplicate_animation_on_repeated_same_transition
    renderer, screen, = make_renderer_and_screen
    2.times do
      renderer.render(screen, two_running_runs(lint: "running"))
      renderer.render(screen, two_running_runs(lint: "completed"))
    end
    # One per run: re-triggering the same (type, run_id, stage) must not add a second
    assert_equal 2, renderer.active_count
  end

  private

  def two_running_runs(**stages)
    [make_run(1, "running", **stages), make_run(2, "running", **stages)]
  end
end

class TestAnimationRendererFrameAdvancement < Minitest::Test
  include AnimationRendererTestHelpers

  def test_should_expire_stage_pass_after_all_frames
    renderer, screen, = make_renderer_and_screen
    renderer.render(screen, [make_run(1, "running", lint: "running")])
    3.times { renderer.render(screen, [make_run(1, "running", lint: "completed")]) }
    refute renderer.any_active?, "stage_pass should expire after its frames"
  end

  def test_should_expire_failure_after_all_animations_finish
    renderer, screen, = make_renderer_and_screen
    renderer.render(screen, [make_run(1, "running", fast: "running")])
    failed = make_run(1, "failed", fast: "failed")
    renderer.render(screen, [failed])
    render_until_idle(renderer, screen, failed)
    refute renderer.any_active?, "All animations should expire eventually"
  end

  def test_should_track_simultaneous_animations
    renderer, screen, = make_renderer_and_screen
    renderer.render(screen, [make_run(1, "running", lint: "running"), make_run(2, "running", build: "running")])
    renderer.render(screen, [make_run(1, "running", lint: "completed"), make_run(2, "running", build: "completed")])
    assert_equal 2, renderer.active_count
  end

  private

  # Failure footers are held 8x per frame, so the header player needs many renders to finish.
  def render_until_idle(renderer, screen, run, max_renders: 60)
    max_renders.times do
      break unless renderer.any_active?

      renderer.render(screen, [run])
    end
  end
end
