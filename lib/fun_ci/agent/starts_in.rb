# frozen_string_literal: true

require_relative "due_in"

module FunCi
  module Agent
    # When a job waiting its turn (Jobs::Schedule) starts, as agents are
    # told it: `starts in 6h`, or `starts now` once its time has come and its
    # process has yet to start it.
    module StartsIn
      def self.words(seconds) = seconds.positive? ? "starts in #{DueIn.words(seconds)}" : "starts now"
    end
  end
end
