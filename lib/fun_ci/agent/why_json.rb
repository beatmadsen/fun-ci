# frozen_string_literal: true

module FunCi
  module Agent
    # `fun-ci why --json` (acceptance-tests.md, AT-10.2): the stage and how it
    # ended, its evidence, or else why there is none. Fields once published
    # keep their names; a change bumps SCHEMA.
    module WhyJson
      SCHEMA = 1
      FAILED = %w[failed over_budget].freeze
      NOTHING_KEPT = { kept: false, bytes: 0 }.freeze

      def self.document(report, stage)
        { schema: SCHEMA, commit: { sha: report.sha, branch: report.branch, subject: report.subject },
          **ending(stage), evidence: evidence(stage), no_evidence: no_evidence(report, stage),
          raw_output: NOTHING_KEPT }
      end

      def self.ending(stage)
        { stage: stage&.name, state: stage&.state, exit_status: stage&.exit_status, signal: stage&.signal,
          seconds: stage&.seconds, budget: stage&.budget }
      end

      def self.evidence(stage) = stage && FAILED.include?(stage.state) ? stage.evidence.to_h : nil

      def self.no_evidence(report, stage)
        return report.verdict == :passed ? "passed" : "running" unless stage

        FAILED.include?(stage.state) ? nil : stage.state
      end
      private_class_method :ending, :evidence, :no_evidence
    end
  end
end
