# frozen_string_literal: true

module FunCi
  module StreakCounter
    PASS_STATUS = "completed"
    ACTIVE_STATUSES = %w[running scheduled].freeze

    # Counts consecutive passed runs from the most recent terminal run.
    # Skips running/scheduled pipelines.
    # Returns nil if no terminal runs exist, 0 if streak is broken.
    def self.count(runs)
      terminal_runs = runs.reject { |r| ACTIVE_STATUSES.include?(r[:status]) }
      return nil if terminal_runs.empty?

      streak = 0
      terminal_runs.each do |run|
        break unless run[:status] == PASS_STATUS
        streak += 1
      end
      streak
    end

    def self.format_text(streak)
      return nil if streak.nil?
      return "Streak broken" if streak == 0

      "#{streak} in a row!"
    end
  end
end
