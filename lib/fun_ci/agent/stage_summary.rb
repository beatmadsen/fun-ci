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

        budget = stage.budget ? ", budget #{stage.budget}s" : ""
        " after #{stage.seconds}s#{budget}"
      end
      private_class_method :ending, :took
    end
  end
end
