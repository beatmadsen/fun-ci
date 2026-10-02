# frozen_string_literal: true

require_relative "age"
require_relative "due_in"
require_relative "starts_in"
require_relative "span"

module FunCi
  module Agent
    # One line per daily or weekly job (acceptance-tests.md, AT-13.22), the
    # names lined up: its cadence, its latest run's state in a word of four
    # letters at most and how long it took, the branch and commit it tested
    # and how long ago it started, as `runs` counts ages, and when the job is
    # due again; then the `why --job`
    # command of each job that failed or ran over budget.
    module JobsText
      WORDS = { "passed" => "ok", "failed" => "FAIL", "lost" => "LOST", "over_budget" => "OVER", "running" => "...",
                "due" => "due", "cancelled" => "x", "scheduled" => "wait" }.freeze

      # now: the time the ages and due times count from.
      def self.lines(reports, now)
        width = reports.map { |report| report.name.size }.max
        reports.map { |report| line(report, width, now) } + whys(reports)
      end

      def self.whys(reports)
        reports.select(&:needs_you?).map { |report| "fun-ci why --job #{report.name}" }
      end

      def self.line(report, width, now)
        head = "#{report.name.ljust(width)}  #{report.cadence.ljust(6)}  #{WORDS.fetch(report.state,
                                                                                       report.state).ljust(4)}"
        return "#{head}  never ran  runs on the next commit" unless report.stage

        "#{head}  #{seconds(report.stage)}  #{tested(report, now)}  #{due(report, now)}"
      end

      # `wip/foo 9e0b1d4  1h ago`; a run waiting its turn has not started.
      def self.tested(report, now)
        commit = "#{report.branch} #{report.sha[0, 7]}"
        report.started_at ? "#{commit}  #{Age.words(now - report.started_at)}" : commit
      end

      def self.seconds(stage) = (stage.seconds ? Span.words(stage.seconds) : "").rjust(6)

      def self.due(report, now)
        return "running" if report.state == "running"
        return StartsIn.words(report.starts_in) if report.starts_in

        report.due_at ? "due in #{DueIn.words(report.due_at - now)}" : "runs on the next commit"
      end
      private_class_method :whys, :line, :tested, :seconds, :due
    end
  end
end
