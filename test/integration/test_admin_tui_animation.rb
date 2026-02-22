# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/admin_tui"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_run"
require "fun_ci/persistence/stage_job"
require "fun_ci/tui/ansi"
require "tmpdir"
require "stringio"

class TestAdminTuiAnimationRenderer < Minitest::Test
  include DatabaseTestSetup
  include PipelineTestHelpers

  def setup
    setup_test_db
    @output = StringIO.new
    @render_calls = []
  end

  def teardown
    teardown_test_db
  end

  def test_should_call_animation_renderer_each_frame
    # Given a TUI with an animation renderer
    create_completed_run("abc1234", "main")
    renderer = make_recording_renderer
    tui = make_tui(animation_renderer: renderer)

    # When we render
    tui.render_once

    # Then the animation renderer should have been called once
    assert_equal 1, @render_calls.length
  end

  def test_should_pass_screen_to_animation_renderer
    # Given a TUI with an animation renderer
    create_completed_run("abc1234", "main")
    renderer = make_recording_renderer
    tui = make_tui(animation_renderer: renderer)

    # When we render
    tui.render_once

    # Then the renderer should receive a Screen
    screen = @render_calls[0][:screen]
    assert_instance_of FunCi::Tui::Screen, screen
  end

  def test_should_pass_current_runs_to_animation_renderer
    # Given a TUI with a completed run
    create_completed_run("abc1234", "main")
    renderer = make_recording_renderer
    tui = make_tui(animation_renderer: renderer)

    # When we render
    tui.render_once

    # Then the renderer should receive the runs data
    runs = @render_calls[0][:runs]
    assert_equal 1, runs.length
    assert_equal "abc1234", runs[0][:commit_hash]
  end

  def test_should_not_fail_when_no_animation_renderer
    # Given a TUI without an animation renderer
    create_completed_run("abc1234", "main")
    tui = make_tui

    # When we render -- it should not raise
    tui.render_once
    plain = FunCi::Tui::Ansi.strip(@output.string)
    assert_match(/abc1234/, plain)
  end

  def test_should_call_animation_renderer_after_clear_below
    # Given a TUI with a renderer that writes an overlay
    create_completed_run("abc1234", "main")
    renderer = make_overlay_renderer("EXPLOSION")
    tui = make_tui(animation_renderer: renderer)

    # When we render
    tui.render_once

    # Then the overlay text should appear after the clear_below sequence
    raw = @output.string
    clear_pos = raw.rindex("\e[J")
    overlay_pos = raw.index("EXPLOSION")
    assert clear_pos, "Output should contain clear_below"
    assert overlay_pos, "Output should contain overlay text"
    assert clear_pos < overlay_pos,
      "Overlay should be rendered after clear_below"
  end

  def test_animation_renderer_receives_runs_on_empty_board
    # Given no pipeline runs
    renderer = make_recording_renderer
    tui = make_tui(animation_renderer: renderer)

    # When we render the empty state
    tui.render_once

    # Then the renderer should still be called with an empty runs array
    assert_equal 1, @render_calls.length
    assert_equal [], @render_calls[0][:runs]
  end

  private

  def make_tui(animation_renderer: nil)
    FunCi::Tui::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      animation_renderer: animation_renderer
    )
  end

  def make_recording_renderer
    calls = @render_calls
    Object.new.tap do |r|
      r.define_singleton_method(:render) do |screen, runs|
        calls << { screen: screen, runs: runs }
      end
    end
  end

  def make_overlay_renderer(text)
    Object.new.tap do |r|
      r.define_singleton_method(:render) do |screen, _runs|
        screen.write_at(5, 10, text)
      end
    end
  end
end
