# frozen_string_literal: true

require_relative "status_text"
require_relative "stage_summary"
require_relative "evidence_text"
require_relative "../persistence/pipeline_recorder"

module FunCi
  module Agent
    # What `fun-ci why` prints about one stage (acceptance-tests.md, AT-10.1):
    # the commit, how the stage ended, then everything kept about it.
    module WhyText
      PASSED = "Nothing is kept about a stage that passed."
      PRUNED = "Its evidence is no longer kept: fun-ci keeps it for a project's " \
               "#{Persistence::DbRecorder::KEPT_RUNS} newest runs.".freeze

      ONLY_TAIL = "Only the output's last lines were kept; extractors under `evidence:` in .fun-ci/config keep more."

      def self.lines(report, stage)
        [StatusText.header(report), StageSummary.line(stage), *body(stage), *raw(report, stage), *only_tail(stage)]
      end

      # So an agent that reads it knows it can write the extractor itself.
      def self.only_tail(stage)
        evidence = stage.evidence
        kept_more = evidence.failures.any? || evidence.excerpts.any? { |excerpt| excerpt[:extractor] != "output-tail" }
        kept_more || evidence.excerpts.empty? ? [] : ["", ONLY_TAIL]
      end

      def self.raw(report, stage)
        stage.raw_bytes ? ["", "The whole output: fun-ci why #{report.sha[0, 7]} #{stage.name} --raw"] : []
      end

      def self.body(stage)
        return [PASSED] if stage.state == "passed"
        return [PRUNED] if stage.pruned?

        EvidenceText.lines(stage.evidence)
      end
      private_class_method :body, :raw, :only_tail
    end
  end
end
