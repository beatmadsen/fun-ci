# frozen_string_literal: true

module FunCi
  module Agent
    # One job as `jobs --json` and `status --json` give it. Fields once
    # published keep their names.
    module JobJson
      def self.document(report)
        stage = report.stage
        { name: report.name, cadence: report.cadence, state: report.state,
          commit: stage && { sha: report.sha, branch: report.branch }, seconds: stage&.seconds,
          started_at: report.started_at&.utc&.iso8601, due_at: report.due_at&.utc&.iso8601, due: report.due? }
      end
    end
  end
end
