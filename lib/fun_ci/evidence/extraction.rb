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
      # An entry that ran; one that didn't is a problem, { extractor:, message: }.
      Ran = Data.define(:name, :findings, :because)

      def initialize(context, budget)
        @context = context
        @budget = budget
      end

      # raw_entries: [[raw entry, why it was chosen], ...]
      def run(raw_entries)
        ran, problems = raw_entries.map { |raw, because| attempt(raw, because) }.partition { |done| done.is_a?(Ran) }
        Result.new(parts: ran.map { |done| [done.name, done.findings] }, problems: problems,
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
        Ran.new(name: entry.name, findings: entry.extractor.extract(@context), because: because)
      rescue Problem => e
        failed(entry.name, e.message)
      rescue StandardError => e
        failed(entry.name, "#{e.class}: #{e.message}")
      end

      def failed(name, message) = { extractor: name, message: message }

      def label(raw) = raw.is_a?(Hash) ? raw["use"] || "run:#{raw["run"]}" : raw.to_s
    end
  end
end
