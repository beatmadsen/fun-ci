# frozen_string_literal: true

module FunCi
  module Evidence
    # How a failed stage ended, known once it has: its state in the words
    # `status --json` uses, its exit status or signal, and the other stages
    # that shared its slot while it ran, and for an overrun, what was found
    # before the kill (an Extraction::Result).
    Outcome = Data.define(:state, :exit_status, :signal, :alongside, :overrun)

    class Outcome
      def initialize(**given) = super(exit_status: nil, signal: nil, alongside: [], overrun: nil, **given)
    end
  end
end
