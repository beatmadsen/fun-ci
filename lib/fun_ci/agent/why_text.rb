# frozen_string_literal: true

require_relative "status_text"
require_relative "stage_summary"
require_relative "evidence_text"

module FunCi
  module Agent
    # What `fun-ci why` prints about one stage (acceptance-tests.md, AT-10.1):
    # the commit, how the stage ended, then everything kept about it.
    module WhyText
      PASSED = "Nothing is kept about a stage that passed."

      def self.lines(report, stage)
        [StatusText.header(report), StageSummary.line(stage), *body(stage)]
      end

      def self.body(stage)
        return [PASSED] if stage.state == "passed"

        EvidenceText.lines(stage.evidence)
      end
      private_class_method :body
    end
  end
end
