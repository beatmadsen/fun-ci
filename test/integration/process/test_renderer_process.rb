# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/process_deadline"
require "fun_ci/console/renderer_process"

# The console's port to the renderer: messages go out as JSON lines on its
# stdin, its lines come back from its stdout, and no wait on it is endless.
class TestRendererProcess < Minitest::Test
  include ProcessDeadline

  ECHO = "while read -r line; do printf '%s\\n' \"$line\"; done"

  def teardown = @renderer && within_deadline { @renderer.finish(patience: 5) }

  def start(script) = @renderer = FunCi::Console::RendererProcess.start(["sh", "-c", script])
  def next_line(patience: 5) = within_deadline { @renderer.next_line(patience: patience) }

  def finish(patience)
    within_deadline { @renderer.finish(patience: patience) }.tap { @renderer = nil }
  end

  def test_should_send_a_message_as_one_json_line
    start(ECHO).write(t: "hello", v: 1)

    assert_equal '{"t":"hello","v":1}', next_line
  end

  def test_should_say_the_renderer_has_ended_once_its_output_closes
    start("exit 0")

    assert_nil next_line
  end

  def test_should_give_up_on_a_renderer_that_stays_silent_past_the_patience
    start("cat > /dev/null")

    assert_raises(FunCi::Console::RendererProcess::Silent) { next_line(patience: 0) }
  end

  def test_should_report_how_the_renderer_exited_once_finished
    start("read -r _; exit 3")

    assert_equal 3, finish(5).exitstatus
  end

  def test_should_stop_a_renderer_that_does_not_exit_within_the_patience
    start("exec tail -f /dev/null")

    refute_predicate finish(0), :success?
  end

  def test_should_kill_a_renderer_that_ignores_being_asked_to_stop
    start("trap '' TERM; echo ignoring; exec tail -f /dev/null")
    next_line

    assert_equal "KILL", Signal.signame(finish(0).termsig)
  end
end
