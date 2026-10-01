# frozen_string_literal: true

module FunCi
  module Agent
    # One line saying how a stage ended: its state, its exit status or the
    # signal that ended it, how long it took and its budget, as far as known.
    module StageSummary
      WORDS = { "over_budget" => "ran over budget" }.freeze

      def self.line(stage)
        "#{stage.name} #{WORDS.fetch(stage.state, stage.state)}#{ending(stage)}#{took(stage)}"
      end

      def self.ending(stage)
        return " (exit #{stage.exit_status})" if stage.exit_status
        return " (killed by SIG#{stage.signal})" if stage.signal

        ""
      end

      def self.took(stage)
        return "" unless stage.seconds

        budget = stage.budget ? ", budget #{budget(stage.budget)}" : ""
        " after #{stage.seconds}s#{budget}"
      end

      # In hours when it is whole hours, as a job's day is: `24h`; else in seconds, `10s`.
      def self.budget(seconds) = seconds >= 3600 && (seconds % 3600).zero? ? "#{seconds / 3600}h" : "#{seconds}s"
      private_class_method :ending, :took, :budget
    end
  end
end
