# frozen_string_literal: true

require_relative "run_report"
require_relative "trunk_json"
require_relative "../evidence/caps"

module FunCi
  module Agent
    # `why REV trunk --json` (design.md, The trunk): the
    # run's trunk, and the conflict as evidence, capped as a stage's is, or
    # why there is none. Fields once published keep their names.
    module TrunkWhyJson
      SCHEMA = 1

      # evidence: an Evidence::Document, or nil when the run's commit doesn't conflict.
      def self.document(report, evidence)
        { schema: SCHEMA, commit: { sha: report.sha, branch: report.branch, subject: report.subject }, stage: "trunk",
          trunk: report.trunk && TrunkJson.document(report.trunk), evidence: evidence && Evidence::Caps.new.apply(evidence).to_h,
          no_evidence: evidence ? nil : "no conflict" }
      end
    end
  end
end
