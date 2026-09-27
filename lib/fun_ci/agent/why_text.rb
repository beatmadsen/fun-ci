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

      def self.lines(report, stage)
        [StatusText.header(report), StageSummary.line(stage), *body(stage), *raw(report, stage)]
      end

      def self.raw(report, stage)
        stage.raw_bytes ? ["", "The whole output: fun-ci why #{report.sha[0, 7]} #{stage.name} --raw"] : []
      end

      def self.body(stage)
        return [PASSED] if stage.state == "passed"
        return [PRUNED] if stage.pruned?

        EvidenceText.lines(stage.evidence)
      end
      private_class_method :body, :raw
    end
  end
end
