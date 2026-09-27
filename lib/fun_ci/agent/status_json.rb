# frozen_string_literal: true

require_relative "run_report"

module FunCi
  module Agent
    # A run report as the JSON document of acceptance-tests.md, AT-9.3.
    # Fields once published keep their names; a change bumps SCHEMA.
    module StatusJson
      SCHEMA = 1

      def self.document(report)
        { schema: SCHEMA, commit: { sha: report.sha, branch: report.branch, subject: report.subject },
          need: report.need, verdict: report.verdict.to_s, stages: report.stages.map { |stage| stage(stage) },
          superseded_by: report.superseded_by }
      end

      def self.unknown(sha) = { schema: SCHEMA, commit: { sha: sha }, verdict: "unknown" }

      def self.stage(stage)
        facts = { name: stage.name, state: stage.state, seconds: stage.seconds }
        stage.failures.any? ? facts.merge(failures: stage.failures) : facts
      end
      private_class_method :stage
    end
  end
end
