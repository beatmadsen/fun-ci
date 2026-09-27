# frozen_string_literal: true

module FunCi
  module Evidence
    # How a failed stage ended, known once it has: its state in the words
    # `status --json` uses, its exit status or signal, and the other stages
    # that shared its slot while it ran.
    Outcome = Data.define(:state, :exit_status, :signal, :alongside)

    class Outcome
      def initialize(exit_status: nil, signal: nil, alongside: [], **) = super
    end
  end
end
