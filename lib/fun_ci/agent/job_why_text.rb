# frozen_string_literal: true

require_relative "stage_summary"
require_relative "evidence_text"
require_relative "span"

module FunCi
  module Agent
    # What `fun-ci why --job NAME` prints (acceptance-tests.md, AT-13.21): the
    # job and the commit its latest run tested, how that run ended, then
    # everything kept about it.
    module JobWhyText
      PASSED = "Nothing is kept about a job that passed."
      RUNNING = "It is still running; fun-ci wait doesn't wait for jobs, so ask again later."
      CANCELLED = "It was cancelled; it runs again on the next commit."

      def self.lines(report)
        summary = StageSummary.line(report.stage, seconds: Span.method(:words))
        [header(report), summary, *body(report.stage), *raw(report), *only_tail(report)]
      end

      def self.header(report) = "fun-ci: job #{report.name} (#{report.cadence}) on #{report.branch} #{report.sha[0, 7]}"

      def self.never_ran(report)
        "fun-ci: job #{report.name} (#{report.cadence}) has not run yet; it runs on the next commit."
      end

      def self.body(stage)
        return [PASSED] if stage.state == "passed"
        return [RUNNING] if stage.state == "running"
        return [CANCELLED] if stage.state == "cancelled"

        EvidenceText.lines(stage.evidence)
      end

      def self.raw(report)
        report.stage.raw_bytes ? ["", "The whole output: fun-ci why --job #{report.name} --raw"] : []
      end

      # So an agent that reads it knows it can write the extractor itself.
      def self.only_tail(report)
        excerpts = report.stage.evidence.excerpts
        return [] if excerpts.empty? || excerpts.any? { |excerpt| excerpt[:extractor] != "output-tail" }

        ["", "Only the output's last lines were kept; extractors under `evidence: jobs: #{report.name}:` " \
             "in .fun-ci/config keep more."]
      end
      private_class_method :body, :raw, :only_tail
    end
  end
end
