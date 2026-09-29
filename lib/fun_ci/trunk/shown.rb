# frozen_string_literal: true

require_relative "check"

module FunCi
  module Trunk
    # A check as the developer and agents are shown it: its state, derived
    # rather than stored, and how many seconds ago its trunk tip was seen
    # (nil when it had none). A run whose check hasn't been recorded is
    # checking until its fetch and merge are past their time, and then unknown.
    Shown = Data.define(:state, :check, :age)

    class Shown
      def self.of(check, now:)
        new(state: state(check.merge), check: check, age: check.tip && (now - check.tip.seen_at))
      end

      def self.unchecked(started:, now:)
        return new(state: "checking", check: nil, age: nil) if now - started <= FETCH_DEADLINE + CHECK_BUDGET

        of(Check.new(commit: nil, tip: nil, merge: Merge.unknown("the check never finished")), now: now)
      end

      def self.state(merge)
        return merge.outcome if merge.outcome == "unknown"
        return "in_trunk" if merge.ahead.zero?

        merge.behind.zero? ? "up_to_date" : merge.outcome
      end
      private_class_method :state
    end
  end
end
