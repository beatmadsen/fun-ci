# frozen_string_literal: true

require_relative "run_report"
require_relative "verdict"

module FunCi
  module Agent
    # A run report as text: the commit, a line per stage with what went wrong
    # in capitals, then the evidence of each needed stage that failed.
    module StatusText
      WORDS = { "failed" => "FAILED", "over_budget" => "OVER BUDGET" }.freeze
      HEADINGS = { "failed" => "failed", "over_budget" => "ran over budget" }.freeze
      EVIDENCE_LINES = 20

      def self.lines(report)
        needed = Verdict::LEVELS.fetch(report.need)
        header = %(fun-ci: #{report.sha[0, 7]} "#{report.subject}" on #{report.branch})
        [header, *report.stages.map { |stage| stage_line(stage, needed) }, *evidence(report.stages, needed),
         *footer(report)]
      end

      def self.stage_line(stage, needed)
        seconds = stage.seconds ? format("%6.1fs", stage.seconds) : " " * 7
        note = needed.include?(stage.name) ? "" : " (not needed)"
        "  #{stage.name.ljust(6)} #{WORDS.fetch(stage.state, stage.state).ljust(12)}#{seconds}#{note}".rstrip
      end

      def self.evidence(stages, needed)
        stages.select { |stage| needed.include?(stage.name) && HEADINGS.key?(stage.state) }
              .flat_map { |stage| evidence_of(stage) }
      end

      def self.evidence_of(stage)
        kept = stage.tail.to_s.lines.last(EVIDENCE_LINES).map { |line| "  #{line.chomp}" }
        ["#{stage.name} #{HEADINGS.fetch(stage.state)}:", *kept]
      end

      def self.footer(report)
        return [] unless report.verdict == :superseded && report.superseded_by

        ["Superseded by #{report.superseded_by[0, 7]}."]
      end
      private_class_method :stage_line, :evidence, :evidence_of, :footer
    end
  end
end
