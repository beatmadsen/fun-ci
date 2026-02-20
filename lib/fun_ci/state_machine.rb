# frozen_string_literal: true

module FunCi
  # Enforced state machine for pipeline runs and stage jobs.
  #
  # States: scheduled, running, completed, failed, timed_out, cancelled
  #
  # Valid transitions:
  #   scheduled -> running
  #   scheduled -> cancelled
  #   running   -> completed
  #   running   -> failed
  #   running   -> timed_out
  #   running   -> cancelled
  class StateMachine
    class InvalidTransition < StandardError; end

    STATES = %i[scheduled running completed failed timed_out cancelled].freeze

    TRANSITIONS = {
      scheduled: %i[running cancelled],
      running: %i[completed failed timed_out cancelled],
      completed: [],
      failed: [],
      timed_out: [],
      cancelled: []
    }.freeze

    TERMINAL_STATES = %i[completed failed timed_out cancelled].freeze

    attr_reader :current_state

    def initialize(initial_state)
      validate_state!(initial_state)
      @current_state = initial_state
    end

    def transition_to!(new_state)
      validate_state!(new_state)
      unless TRANSITIONS.fetch(@current_state).include?(new_state)
        raise InvalidTransition,
          "Cannot transition from #{@current_state} to #{new_state}"
      end
      @current_state = new_state
    end

    def terminal?
      TERMINAL_STATES.include?(@current_state)
    end

    private

    def validate_state!(state)
      return if STATES.include?(state)

      raise ArgumentError, "Unknown state: #{state}. Valid states: #{STATES.join(", ")}"
    end
  end
end
