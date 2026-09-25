# frozen_string_literal: true

require_relative "../tui/stage_change_detector"

module FunCi
  module Console
    # The protocol `event` messages for the stages that changed since the
    # last poll of the runs: one that failed or timed out, or one that
    # passed. The renderer chooses the animation (renderer-protocol.md).
    class StageEvents
      NAMES = { "failed" => "stage_failed", "timed_out" => "stage_failed", "completed" => "stage_passed" }.freeze

      def initialize
        @previous = []
      end

      # None on the first poll, which has nothing to compare with.
      def since_last(runs)
        changes = Tui::StageChangeDetector.detect(@previous, runs)
        @previous = runs
        changes.select { |change| NAMES.key?(change.to) }.map { |change| event(change) }
      end

      private

      def event(change)
        { t: "event", name: NAMES.fetch(change.to), run_id: change.run_id, stage: change.stage }
      end
    end
  end
end
