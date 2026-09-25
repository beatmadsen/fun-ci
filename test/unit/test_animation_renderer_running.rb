# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/animation_renderer"
require "fun_ci/tui/screen"
require "fun_ci/tui/ansi"
require "stringio"

class TestAnimationRendererRunningState < Minitest::Test
  include AnimationRendererTestHelpers

  # Enough frames for any event animation to play out.
  EVENT_ANIMATION_FRAME_BUDGET = 60

  def setup
    @renderer, @screen, @output = make_renderer_and_screen
  end

  def test_should_show_running_animation_when_pipeline_is_running
    render(make_run(1, "pending"))
    render(make_run(1, "running", lint: "running"))
    plain = fresh_render(make_run(1, "running", lint: "running"))
    assert_match(/running-/, plain, "Should show running animation in header")
  end

  def test_should_show_idle_when_no_pipeline_running
    render(make_run(1, "completed", lint: "completed"))
    plain = fresh_render(make_run(1, "completed", lint: "completed"))
    assert_match(/idle-/, plain, "Should show idle when nothing is running")
  end

  def test_should_stop_running_animation_when_pipeline_completes
    2.times { render(make_run(1, "running", lint: "running")) }
    completed = make_run(1, "completed", slow: "completed")
    render_until_event_animations_expire(completed)
    plain = fresh_render(completed)
    assert_match(/idle-/, plain, "Should return to idle after pipeline completes")
    refute_match(/running-/, plain, "Should not show running content")
  end

  def test_should_show_running_when_any_pipeline_is_running
    runs = [make_run(1, "completed", lint: "completed"), make_run(2, "running", lint: "running")]
    render(*runs)
    plain = fresh_render(*runs)
    assert_match(/running-/, plain, "Should show running when any pipeline is active")
  end

  private

  def render(*runs)
    @renderer.render(@screen, runs)
  end

  def fresh_render(*runs)
    @output.truncate(0)
    @output.rewind
    render(*runs)
    FunCi::Tui::Ansi.strip(@output.string)
  end

  def render_until_event_animations_expire(run)
    render(run)
    EVENT_ANIMATION_FRAME_BUDGET.times do
      break unless @renderer.any_active?

      render(run)
    end
  end
end
