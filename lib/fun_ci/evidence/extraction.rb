# frozen_string_literal: true

require_relative "catalog"
require_relative "problem"

module FunCi
  module Evidence
    # Runs a stage's entries in order within the budget: an entry that is
    # mistaken, raises, or comes after the deadline is a problem, and the
    # others still run.
    class Extraction
      # parts: [[name, findings], ...] in order; chosen: [{ extractor:, because: }].
      Result = Data.define(:parts, :problems, :chosen)
      Attempt = Data.define(:name, :findings, :because, :problem)

      def initialize(context, budget)
        @context = context
        @budget = budget
      end

      # raw_entries: [[raw entry, why it was chosen], ...]
      def run(raw_entries)
        attempts = raw_entries.map { |raw, because| attempt(raw, because) }
        ran = attempts.reject(&:problem)
        Result.new(parts: ran.map { |done| [done.name, done.findings] }, problems: attempts.filter_map(&:problem),
                   chosen: ran.map { |done| { extractor: done.name, because: done.because } })
      end

      private

      def attempt(raw, because)
        entry = Catalog.entry(raw)
        return failed(entry.name, "not run: the evidence budget of #{@budget}s ran out") if @context.deadline.passed?

        ran(entry, because)
      rescue Catalog::Refused => e
        failed(label(raw), e.message)
      end

      # Whatever an extractor raises is a problem, never the end of the evidence.
      def ran(entry, because)
        Attempt.new(name: entry.name, findings: entry.extractor.extract(@context), because: because, problem: nil)
      rescue Problem => e
        failed(entry.name, e.message)
      rescue StandardError => e
        failed(entry.name, "#{e.class}: #{e.message}")
      end

      def failed(name, message)
        Attempt.new(name: name, findings: nil, because: nil, problem: { extractor: name, message: message })
      end

      def label(raw) = raw.is_a?(Hash) ? raw["use"] || "run:#{raw["run"]}" : raw.to_s
    end
  end
end
