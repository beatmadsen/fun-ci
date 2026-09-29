# frozen_string_literal: true

require_relative "check"

module FunCi
  module Trunk
    # A check as the developer and agents are shown it: its state, derived
    # rather than stored, and how many seconds ago its trunk SHA was seen.
    Shown = Data.define(:state, :check, :age)

    class Shown
      def self.of(check, now:) = new(state: state(check), check: check, age: now - check.seen_at)

      def self.state(check)
        return check.outcome if check.outcome == "unknown"
        return "in_trunk" if check.ahead.zero?

        check.behind.zero? ? "up_to_date" : check.outcome
      end
      private_class_method :state
    end
  end
end
