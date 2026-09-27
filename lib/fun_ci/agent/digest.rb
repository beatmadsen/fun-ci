# frozen_string_literal: true

module FunCi
  module Agent
    # Why a needed stage failed, as text (acceptance-tests.md, AT-9.6): the
    # failures it reported, or else the last lines of its output.
    module Digest
      HEADINGS = { "failed" => "failed", "over_budget" => "ran over budget" }.freeze
      TAIL_LINES = 20
      FAILURES = 10
      MESSAGE_LINES = 5

      def self.lines(stages, needed)
        stages.select { |stage| needed.include?(stage.name) && HEADINGS.key?(stage.state) }
              .flat_map { |stage| of(stage) }
      end

      def self.of(stage)
        details = stage.failures.any? ? failure_lines(stage.failures) : tail_lines(stage.tail)
        ["#{stage.name} #{HEADINGS.fetch(stage.state)}:", *details]
      end

      def self.failure_lines(failures)
        failures.first(FAILURES).flat_map do |failure|
          ["  #{place(failure)}", *failure[:message].lines.first(MESSAGE_LINES).map { |line| "    #{line.chomp}" }]
        end
      end

      def self.place(failure)
        failure[:file] ? "#{failure[:file]}:#{failure[:line]}  #{failure[:test]}" : failure[:test]
      end

      def self.tail_lines(tail) = tail.to_s.lines.last(TAIL_LINES).map { |line| "  #{line.chomp}" }
      private_class_method :of, :failure_lines, :place, :tail_lines
    end
  end
end
