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
          **times(report), due: report.due? }
      end

      # When its latest run started, or, while it waits its turn, is to start
      # (Jobs::Schedule), and when it is due again.
      def self.times(report)
        { started_at: iso(report.started_at), starts_at: iso(report.starts_at), due_at: iso(report.due_at) }
      end

      def self.iso(time) = time&.utc&.iso8601
      private_class_method :times, :iso
    end
  end
end
