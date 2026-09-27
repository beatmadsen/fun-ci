# frozen_string_literal: true

module FunCi
  module Agent
    # Why a needed stage failed, as the short text `status` and `wait` print
    # (acceptance-tests.md, AT-9.6, AT-10.17), drawn from its evidence: for an
    # overrun, what it was running; then the failures, or else the first
    # excerpt, or else the output's last lines.
    module Digest
      HEADINGS = { "failed" => "failed", "over_budget" => "ran over budget" }.freeze
      LINES = 20
      FAILURES = 10
      MESSAGE_LINES = 5

      def self.lines(stages, needed)
        stages.select { |stage| needed.include?(stage.name) && HEADINGS.key?(stage.state) }
              .flat_map { |stage| of(stage) }
      end

      def self.of(stage)
        evidence = stage.evidence
        [heading(stage, evidence), *(evidence.failures.any? ? failure_lines(evidence.failures) : excerpt(evidence))]
      end

      def self.heading(stage, evidence)
        running = evidence.facts.find { |fact| fact[:name] == "running" }
        "#{stage.name} #{HEADINGS.fetch(stage.state)}:#{" running #{running[:value]}" if running}"
      end

      def self.failure_lines(failures)
        failures.first(FAILURES).flat_map do |failure|
          ["  #{place(failure)}", *failure[:message].to_s.lines.first(MESSAGE_LINES).map { |line| "    #{line.chomp}" }]
        end
      end

      def self.place(failure)
        failure[:file] ? "#{failure[:file]}:#{failure[:line]}  #{failure[:test]}" : failure[:test]
      end

      # The first excerpt's first lines, or the output's last lines.
      def self.excerpt(evidence)
        first = evidence.excerpts.find { |excerpt| excerpt[:extractor] != "output-tail" }
        lines = first ? first[:lines].first(LINES) : evidence.excerpts.flat_map { |e| e[:lines] }.last(LINES)
        lines.map { |line| "  #{line}" }
      end
      private_class_method :of, :heading, :failure_lines, :place, :excerpt
    end
  end
end
