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
    create_completed_run("abc1234", "main")
    render_with(recording_renderer)
    assert_equal 1, @render_calls.length
  end

  def test_should_pass_screen_to_animation_renderer
    create_completed_run("abc1234", "main")
    render_with(recording_renderer)
    assert_instance_of FunCi::Tui::Screen, @render_calls[0][:screen]
  end

  def test_should_pass_current_runs_to_animation_renderer
    create_completed_run("abc1234", "main")
    render_with(recording_renderer)
    runs = @render_calls[0][:runs]
    assert_equal 1, runs.length
    assert_equal "abc1234", runs[0][:commit_hash]
  end

  def test_should_not_fail_when_no_animation_renderer
    create_completed_run("abc1234", "main")
    render_with(nil)
    assert_match(/abc1234/, FunCi::Tui::Ansi.strip(@output.string))
  end

  def test_should_call_animation_renderer_after_clear_below
    create_completed_run("abc1234", "main")
    render_with(overlay_renderer("EXPLOSION"))
    clear_pos = @output.string.rindex("\e[J")
    overlay_pos = @output.string.index("EXPLOSION")
    assert clear_pos, "Output should contain clear_below"
    assert overlay_pos, "Output should contain overlay text"
    assert clear_pos < overlay_pos, "Overlay should be rendered after clear_below"
  end

  def test_animation_renderer_receives_runs_on_empty_board
    render_with(recording_renderer)
    assert_equal 1, @render_calls.length
    assert_equal [], @render_calls[0][:runs]
  end

  private

  def render_with(animation_renderer)
    FunCi::Tui::AdminTui.new(
      db: @db, output: @output, input: StringIO.new(""),
      animation_renderer: animation_renderer
    ).render_once
  end

  def recording_renderer
    calls = @render_calls
    Object.new.tap do |r|
      r.define_singleton_method(:render) { |screen, runs| calls << { screen: screen, runs: runs } }
    end
  end

  def overlay_renderer(text)
    Object.new.tap do |r|
      r.define_singleton_method(:render) { |screen, _runs| screen.write_at(5, 10, text) }
    end
  end
end
