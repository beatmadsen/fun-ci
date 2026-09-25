# frozen_string_literal: true

module FunCi
  module Console
    module StreakCounter
      PASS_STATUS = "completed"
      ACTIVE_STATUSES = %w[running scheduled].freeze

      # Passed runs since the latest finished run that did not pass; nil
      # while no run has finished.
      def self.count(runs)
        finished = runs.reject { |run| ACTIVE_STATUSES.include?(run[:status]) }
        return nil if finished.empty?

        finished.take_while { |run| run[:status] == PASS_STATUS }.size
      end

      def self.format_text(streak)
        return nil if streak.nil?
        return "Streak broken" if streak.zero?

        "#{streak} in a row!"
      end
    end
  end
end
