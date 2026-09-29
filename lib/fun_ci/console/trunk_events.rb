# frozen_string_literal: true

module FunCi
  module Console
    # The header's events for the trunk (design.md, The
    # trunk): trunk_conflict when a branch's standing becomes conflicts,
    # trunk_clear when it moves from conflicts to another settled standing,
    # each at most once a poll however many branches changed, naming one
    # branch's newest run and how many. A branch keeps its standing through
    # a poll that shows none, and the first poll has nothing to compare with.
    class TrunkEvents
      def initialize
        @standing = nil
      end

      # runs: as TrunkMarks marks them, newest first.
      def since_last(runs)
        now = standings(runs)
        events = @standing ? [started(now), stopped(now)].compact : []
        @standing = (@standing || {}).merge(now)
        events
      end

      private

      # { [project, branch] => [newest run id, standing] }
      def standings(runs)
        runs.select { |run| run[:trunk] }.to_h do |run|
          [run.values_at(:project_path, :branch), [run[:id], run[:trunk][:branch_state]]]
        end
      end

      def started(now) = event("trunk_conflict", now.select { |key, (_, state)| conflicts?(state) && !was?(key) })
      def stopped(now) = event("trunk_clear", now.select { |key, (_, state)| !conflicts?(state) && was?(key) })
      def was?(key) = conflicts?(@standing.dig(key, 1))
      def conflicts?(state) = state == "conflicts"

      def event(name, branches)
        branches.empty? ? nil : { t: "event", name: name, run_id: branches.values.first.first, branches: branches.size }
      end
    end
  end
end
