# frozen_string_literal: true

module FunCi
  module Agent
    # The verdict for an agent that asks with --trunk (docs/trunk-conflicts.md,
    # status and wait): a failure stays one whatever the trunk says; a passed
    # run is undecided while its check is going and in conflict when it
    # conflicts. A trunk that couldn't be checked leaves the verdict alone:
    # its causes are the project's, and would fail every run until fixed.
    module TrunkVerdict
      BY_STATE = { "checking" => :undecided, "conflicts" => :conflicts }.freeze

      def self.of(verdict, shown)
        return verdict unless verdict == :passed && shown

        BY_STATE.fetch(shown.state, verdict)
      end
    end
  end
end
