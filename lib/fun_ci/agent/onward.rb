# frozen_string_literal: true

module FunCi
  module Agent
    # What a wait does once the run it waited on is decided
    # (acceptance-tests.md, AT-9.12, AT-9.21): `:follow` the branch to the
    # commit that superseded the run, `:run_again` its own commit, once, or
    # `:stop` with the report.
    module Onward
      # report: the decided report, nil when no run turned up; ran_again:
      # whether this wait has run its commit again already.
      def self.decide(report, follow_branch:, ran_again:)
        return :stop unless report&.superseded_by
        return :follow if follow_branch
        return :run_again if report.verdict == :superseded && !ran_again

        :stop
      end
    end
  end
end
