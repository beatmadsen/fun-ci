# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/state_machine"

class TestStateMachineValidTransitions < Minitest::Test
  def test_should_transition_from_scheduled_to_running
    # Given a state machine in the scheduled state
    sm = FunCi::StateMachine.new(:scheduled)
    # When we transition to running
    sm.transition_to!(:running)
    # Then the current state should be running
    assert_equal :running, sm.current_state, "Should be in running state after transition from scheduled"
  end

  def test_should_transition_from_running_to_completed
    # Given a state machine in the running state
    sm = FunCi::StateMachine.new(:running)
    # When we transition to completed
    sm.transition_to!(:completed)
    # Then the current state should be completed
    assert_equal :completed, sm.current_state, "Should be in completed state after transition from running"
  end

  def test_should_transition_from_running_to_failed
    # Given a state machine in the running state
    sm = FunCi::StateMachine.new(:running)
    # When we transition to failed
    sm.transition_to!(:failed)
    # Then the current state should be failed
    assert_equal :failed, sm.current_state, "Should be in failed state after transition from running"
  end

  def test_should_transition_from_running_to_timed_out
    # Given a state machine in the running state
    sm = FunCi::StateMachine.new(:running)
    # When we transition to timed_out
    sm.transition_to!(:timed_out)
    # Then the current state should be timed_out
    assert_equal :timed_out, sm.current_state, "Should be in timed_out state after transition from running"
  end

  def test_should_transition_from_scheduled_to_cancelled
    # Given a state machine in the scheduled state
    sm = FunCi::StateMachine.new(:scheduled)
    # When we transition to cancelled
    sm.transition_to!(:cancelled)
    # Then the current state should be cancelled
    assert_equal :cancelled, sm.current_state, "Should be in cancelled state after transition from scheduled"
  end

  def test_should_transition_from_running_to_cancelled
    # Given a state machine in the running state
    sm = FunCi::StateMachine.new(:running)
    # When we transition to cancelled
    sm.transition_to!(:cancelled)
    # Then the current state should be cancelled
    assert_equal :cancelled, sm.current_state, "Should be in cancelled state after transition from running"
  end
end

class TestStateMachineInvalidTransitions < Minitest::Test
  def test_should_raise_when_transitioning_from_scheduled_to_completed
    # Given a state machine in the scheduled state
    sm = FunCi::StateMachine.new(:scheduled)
    # When we attempt to transition directly to completed
    # Then it should raise InvalidTransition
    error = assert_raises(FunCi::StateMachine::InvalidTransition) do
      sm.transition_to!(:completed)
    end
    assert_match(/scheduled.*completed/i, error.message,
      "Error message should mention both the current and target states")
  end

  def test_should_raise_when_transitioning_from_completed_to_running
    # Given a state machine in the completed state
    sm = FunCi::StateMachine.new(:completed)
    # When we attempt to transition back to running
    # Then it should raise InvalidTransition
    assert_raises(FunCi::StateMachine::InvalidTransition) do
      sm.transition_to!(:running)
    end
  end

  def test_should_raise_when_transitioning_from_failed_to_running
    # Given a state machine in the failed state
    sm = FunCi::StateMachine.new(:failed)
    # When we attempt to transition back to running
    # Then it should raise InvalidTransition
    assert_raises(FunCi::StateMachine::InvalidTransition) do
      sm.transition_to!(:running)
    end
  end

  def test_should_raise_when_transitioning_from_timed_out_to_anything
    # Given a state machine in the timed_out state
    sm = FunCi::StateMachine.new(:timed_out)
    # When we attempt any transition
    # Then it should raise InvalidTransition for all targets
    [:scheduled, :running, :completed, :failed, :cancelled].each do |target|
      assert_raises(FunCi::StateMachine::InvalidTransition,
        "Should not allow transition from timed_out to #{target}") do
        sm.transition_to!(target)
      end
    end
  end

  def test_should_raise_when_transitioning_from_cancelled_to_anything
    # Given a state machine in the cancelled state
    sm = FunCi::StateMachine.new(:cancelled)
    # When we attempt any transition
    # Then it should raise InvalidTransition for all targets
    [:scheduled, :running, :completed, :failed, :timed_out].each do |target|
      assert_raises(FunCi::StateMachine::InvalidTransition,
        "Should not allow transition from cancelled to #{target}") do
        sm.transition_to!(target)
      end
    end
  end
end

class TestStateMachineInitialization < Minitest::Test
  def test_should_start_in_the_given_initial_state
    # Given we create a state machine with scheduled as initial state
    sm = FunCi::StateMachine.new(:scheduled)
    # Then the current state should be scheduled
    assert_equal :scheduled, sm.current_state, "Should start in the initial state provided"
  end

  def test_should_raise_when_initialized_with_unknown_state
    # Given an invalid state name
    # When we create a state machine with that state
    # Then it should raise ArgumentError
    assert_raises(ArgumentError) do
      FunCi::StateMachine.new(:bogus)
    end
  end
end

class TestStateMachineQueryMethods < Minitest::Test
  def test_should_report_terminal_state_for_completed
    # Given a state machine in the completed state
    sm = FunCi::StateMachine.new(:completed)
    # Then it should be terminal
    assert sm.terminal?, "Completed should be a terminal state"
  end

  def test_should_report_terminal_state_for_failed
    sm = FunCi::StateMachine.new(:failed)
    assert sm.terminal?, "Failed should be a terminal state"
  end

  def test_should_report_terminal_state_for_timed_out
    sm = FunCi::StateMachine.new(:timed_out)
    assert sm.terminal?, "Timed out should be a terminal state"
  end

  def test_should_report_terminal_state_for_cancelled
    sm = FunCi::StateMachine.new(:cancelled)
    assert sm.terminal?, "Cancelled should be a terminal state"
  end

  def test_should_not_report_terminal_state_for_scheduled
    sm = FunCi::StateMachine.new(:scheduled)
    refute sm.terminal?, "Scheduled should not be a terminal state"
  end

  def test_should_not_report_terminal_state_for_running
    sm = FunCi::StateMachine.new(:running)
    refute sm.terminal?, "Running should not be a terminal state"
  end
end
