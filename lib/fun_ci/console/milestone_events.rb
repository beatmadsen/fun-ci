# frozen_string_literal: true

require_relative "milestones"

module FunCi
  module Console
    # The protocol `event` for each milestone a run reached since the last
    # poll (acceptance-tests.md, AT-7.2). None on the first poll, which has
    # nothing to compare with; none for a cancelled run; and none once a run
    # has failed, so a run fails once however many of its stages fail.
    class MilestoneEvents
      def initialize
        @previous = nil
      end

      def since_last(runs)
        events = @previous ? runs.flat_map { |run| new_milestones(run) } : []
        @previous = runs.to_h { |run| [run[:id], Milestones.of(run)] }
        events
      end

      private

      def new_milestones(run)
        before = @previous.fetch(run[:id], [])
        return [] if before.include?("run_failed") || run[:status] == "cancelled"

        (Milestones.of(run) - before).map { |name| { t: "event", name: name, run_id: run[:id] } }
      end
    end
  end
end
