# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/gate"

# The pipe a stage's shell waits on until the caller has recorded its pid.
class TestGate < Minitest::Test
  def setup
    @gate = FunCi::Pipeline::Gate.create
  end

  def teardown
    @gate.child_end.close unless @gate.child_end.closed?
  end

  # Ruby makes pipes non-blocking, and the child shares the setting: a shell
  # reaching `read` before the caller opened the gate got EAGAIN and gave up,
  # so the stage never ran (exit 125).
  def test_should_hand_the_child_an_end_that_waits
    refute_predicate @gate.child_end, :nonblock?
  end

  def test_should_let_the_child_read_a_line_once_opened
    @gate.open

    assert_equal "\n", @gate.child_end.gets
  end

  def test_should_leave_nothing_more_to_read_once_opened
    @gate.open
    @gate.child_end.gets

    assert_nil @gate.child_end.gets
  end

  def test_should_open_quietly_when_the_child_has_gone
    @gate.child_end.close

    assert_nil @gate.open
  end
end
