# frozen_string_literal: true

module FunCi
  module Agent
    # `fun-ci why --job NAME --json` (acceptance-tests.md, AT-13.21): the job,
    # how its latest run ended, its evidence, or else why there is none, as
    # `why --json` gives them for a stage. Fields once published keep their
    # names; a change bumps SCHEMA.
    module JobWhyJson
      SCHEMA = 1

      def self.document(report)
        stage = report.stage
        { schema: SCHEMA, name: report.name, cadence: report.cadence, state: report.state,
          commit: stage && { sha: report.sha, branch: report.branch }, **ending(stage), **evidence(report),
          raw_output: { kept: !stage&.raw_bytes.nil?, bytes: stage&.raw_bytes || 0 } }
      end

      # The evidence of a run that failed or ran over budget, or else why there is none.
      def self.evidence(report)
        failed = report.needs_you?
        { evidence: failed ? report.stage.evidence.to_h : nil, no_evidence: failed ? nil : report.state }
      end

      def self.ending(stage)
        { exit_status: stage&.exit_status, signal: stage&.signal, seconds: stage&.seconds, budget: stage&.budget }
      end
      private_class_method :ending, :evidence
    end
  end
end
