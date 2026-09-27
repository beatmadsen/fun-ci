# frozen_string_literal: true

require_relative "run_report"
require_relative "verdict"
require_relative "digest"

module FunCi
  module Agent
    # A run report as text: the commit, a line per stage with what went wrong
    # in capitals, then the evidence of each needed stage that failed.
    module StatusText
      WORDS = { "failed" => "FAILED", "over_budget" => "OVER BUDGET" }.freeze

      def self.lines(report)
        needed = Verdict::LEVELS.fetch(report.need)
        [header(report), *report.stages.map { |stage| stage_line(stage, needed) }, *Digest.lines(report.stages, needed),
         *footer(report)]
      end

      def self.header(report) = %(fun-ci: #{report.sha[0, 7]} "#{report.subject}" on #{report.branch})

      def self.stage_line(stage, needed)
        seconds = stage.seconds ? format("%6.1fs", stage.seconds) : " " * 7
        note = needed.include?(stage.name) ? "" : " (not needed)"
        "  #{stage.name.ljust(6)} #{WORDS.fetch(stage.state, stage.state).ljust(12)}#{seconds}#{note}".rstrip
      end

      def self.footer(report)
        return [] unless report.verdict == :superseded && report.superseded_by

        ["Superseded by #{report.superseded_by[0, 7]}."]
      end
      private_class_method :stage_line, :footer
    end
  end
end
