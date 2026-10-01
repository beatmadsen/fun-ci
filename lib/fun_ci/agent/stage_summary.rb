# frozen_string_literal: true

module FunCi
  module Agent
    # One line saying how a stage ended: its state, its exit status or the
    # signal that ended it, how long it took and its budget, as far as known.
    module StageSummary
      WORDS = { "over_budget" => "ran over budget" }.freeze

      # seconds: how a length of time is said; in seconds by default, `1.4s`.
      def self.line(stage, seconds: ->(time) { "#{time}s" })
        "#{stage.name} #{WORDS.fetch(stage.state, stage.state)}#{ending(stage)}#{took(stage, seconds)}"
      end

      def self.ending(stage)
        return " (exit #{stage.exit_status})" if stage.exit_status
        return " (killed by SIG#{stage.signal})" if stage.signal

        ""
      end

      def self.took(stage, seconds)
        return "" unless stage.seconds

        budget = stage.budget ? ", budget #{budget(stage.budget)}" : ""
        " after #{seconds.call(stage.seconds)}#{budget}"
      end

      # In hours when it is whole hours, as a job's day is: `24h`; else in seconds, `10s`.
      def self.budget(seconds) = seconds >= 3600 && (seconds % 3600).zero? ? "#{seconds / 3600}h" : "#{seconds}s"
      private_class_method :ending, :took, :budget
    end
  end
end
