# frozen_string_literal: true

require_relative "check"

module FunCi
  module Trunk
    # A check as the developer and agents are shown it: its state, derived
    # rather than stored, and how many seconds ago its trunk tip was seen
    # (nil when it had none).
    Shown = Data.define(:state, :check, :age)

    class Shown
      def self.of(check, now:)
        new(state: state(check.merge), check: check, age: check.tip && (now - check.tip.seen_at))
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
