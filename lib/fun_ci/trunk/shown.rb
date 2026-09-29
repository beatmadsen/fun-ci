# frozen_string_literal: true

require_relative "check"

module FunCi
  module Trunk
    # A check as the developer and agents are shown it: its state, derived
    # rather than stored, how many seconds ago its trunk tip was seen (nil
    # when it had none), the project's last fetch (a LastFetch, nil if none), and
    # the SHA the trunk has moved to since, if it has.
    # A run whose check hasn't been recorded is checking until its fetch and
    # merge are past their time, and then unknown.
    Shown = Data.define(:state, :check, :age, :fetch, :moved_to)

    class Shown
      # How old a trunk may be before it is stale.
      FRESH_FOR = 3600

      def self.of(check, now:, fetch: nil, moved_to: nil)
        new(state: state(check.merge), check: check, age: check.tip && (now - check.tip.seen_at),
            fetch: fetch, moved_to: moved_to)
      end

      def self.unchecked(started:, now:)
        if now - started <= FETCH_DEADLINE + CHECK_BUDGET
          return new(state: "checking", check: nil, age: nil, fetch: nil, moved_to: nil)
        end

        of(Check.new(commit: nil, tip: nil, merge: Merge.unknown("the check never finished")), now: now)
      end

      def self.state(merge)
        return merge.outcome if merge.outcome == "unknown"
        return "in_trunk" if merge.ahead.zero?

        merge.behind.zero? ? "up_to_date" : merge.outcome
      end
      private_class_method :state

      # Whether the trunk it was checked against may have moved on unseen.
      def stale? = !fetch_error.nil? || (!age.nil? && age > FRESH_FOR)

      # Why the project's last fetch failed, or nil.
      def fetch_error = fetch&.error
    end
  end
end
