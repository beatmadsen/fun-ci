# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/console/console_loop"

# AT-5.1: the console hands each line the renderer writes to the session,
# polls the runs whenever the renderer has been quiet for a while, and stops
# when the session quits or the renderer goes away.
class TestConsoleLoop < Minitest::Test
  # Answers from `script`: a String is a line, :silent is no line within the
  # patience, :end is the renderer closing its output. Reading past the
  # script fails the test, so a loop that never stops cannot spin.
  class ScriptedRenderer
    def initialize(script)
      @script = script.dup
    end

    def next_line(patience:)
      raise Minitest::Assertion, "the loop read past the script (patience #{patience})" if @script.empty?

      item = @script.shift
      raise FunCi::Console::RendererProcess::Silent if item == :silent

      item == :end ? nil : item
    end
  end

  # Records what the loop asks of it, and quits on the line "q".
  class RecordingSession
    attr_reader :calls

    def initialize
      @calls = []
    end

    def start = @calls << :start
    def refresh = @calls << :refresh
    def finished? = @calls.include?([:receive, "q"])
    def receive(line) = @calls << [:receive, line]
  end

  def setup = @session = RecordingSession.new
  def run_loop(*script) = FunCi::Console::ConsoleLoop.new(session: @session, renderer: ScriptedRenderer.new(script)).run

  def test_should_start_the_session_before_anything_else
    run_loop("q")

    assert_equal :start, @session.calls.first
  end

  def test_should_hand_each_renderer_line_to_the_session_in_order
    run_loop("a", "b", "q")

    assert_equal [[:receive, "a"], [:receive, "b"]], @session.calls[1, 2]
  end

  def test_should_poll_the_runs_when_the_renderer_is_quiet
    run_loop(:silent, "q")

    assert_equal :refresh, @session.calls[1]
  end

  def test_should_carry_on_after_a_quiet_spell
    assert_equal :quit, run_loop(:silent, "q")
  end

  def test_should_stop_once_the_session_has_quit
    assert_equal :quit, run_loop("q")
  end

  def test_should_stop_when_the_renderer_goes_away
    assert_equal :ended, run_loop("a", :end)
  end
end
