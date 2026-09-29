# frozen_string_literal: true

require_relative "stage_events"
require_relative "milestone_events"
require_relative "trunk_events"

module FunCi
  module Console
    # Every protocol `event` since the last poll of the runs: the stages that
    # changed (for the effects on a stage's column), then the milestones the
    # runs reached, then branches starting or stopping conflicting with the
    # trunk (both for the header).
    class ConsoleEvents
      def initialize
        @stages = StageEvents.new
        @milestones = MilestoneEvents.new
        @trunk = TrunkEvents.new
      end

      def since_last(runs) = @stages.since_last(runs) + @milestones.since_last(runs) + @trunk.since_last(runs)
    end
  end
end
