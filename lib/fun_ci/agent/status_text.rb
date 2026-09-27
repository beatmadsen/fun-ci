# frozen_string_literal: true

require_relative "run_report"
require_relative "verdict"

module FunCi
  module Agent
    # A run report as text: the commit, then a line per stage, with what went
    # wrong in capitals so it stands out.
    module StatusText
      WORDS = { "failed" => "FAILED", "over_budget" => "OVER BUDGET" }.freeze

      def self.lines(report)
        header = %(fun-ci: #{report.sha[0, 7]} "#{report.subject}" on #{report.branch})
        [header, *report.stages.map { |stage| stage_line(stage, Verdict::LEVELS.fetch(report.need)) }, *footer(report)]
      end

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
