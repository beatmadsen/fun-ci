# frozen_string_literal: true

require_relative "run_report"

module FunCi
  module Agent
    # One line per run, the columns lined up: short SHA, branch, age, each
    # stage's outcome in a word of four letters at most, and the subject.
    module RunsText
      WORDS = { "passed" => "ok", "failed" => "FAIL", "over_budget" => "OVER", "running" => "...", "waiting" => "-",
                "cancelled" => "x" }.freeze

      # entries: [[report, age in words], ...], newest first.
      def self.lines(entries)
        widths = [entries.map { |report, _| report.branch.size }.max, entries.map { |_, age| age.size }.max]
        entries.map { |report, age| line(report, age, widths) }
      end

      def self.line(report, age, (branch_width, age_width))
        stages = report.stages.map { |stage| "#{stage.name} #{WORDS.fetch(stage.state).ljust(4)}" }.join("  ")
        "#{report.sha[0,
                      7]}  #{report.branch.ljust(branch_width)}  #{age.ljust(age_width)}  #{stages}  #{report.subject}"
      end
      private_class_method :line
    end
  end
end
