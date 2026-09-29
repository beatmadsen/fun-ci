# frozen_string_literal: true

require "json"

module FunCi
  module Evidence
    # What fun-ci kept about why a stage failed (architecture.md, "Evidence of a failed stage"): the extractors
    # chosen and why, facts, failures, excerpts, and the problems extractors
    # had. Each item is a hash naming the extractor that found it.
    Document = Data.define(:chosen, :facts, :failures, :excerpts, :problems)

    class Document
      TAIL_TITLE = "The output's last lines"

      # A document as fun-ci kept it; a list it doesn't have is empty.
      def self.from_json(text)
        parsed = JSON.parse(text, symbolize_names: true)
        new(**members.to_h { |member| [member, parsed.fetch(member, [])] })
      end

      # The evidence from each extractor's findings, [name, findings] in the
      # order they are shown, each item crediting the extractor that found
      # it; the same failure found twice is kept where it was found first.
      def self.assemble(parts, problems:, chosen:)
        failures = credited(parts, :failures).uniq { |failure| failure.values_at(:test, :file, :line) }
        new(chosen: chosen, facts: credited(parts, :facts), failures: failures,
            excerpts: credited(parts, :excerpts), problems: problems)
      end

      def self.credited(parts, list)
        parts.flat_map { |name, found| found.public_send(list).map { |item| item.merge(extractor: name) } }
      end

      # The evidence of a stage whose collecting went wrong: what went wrong.
      def self.broken(message)
        new(chosen: [], facts: [], failures: [], excerpts: [],
            problems: [{ extractor: "fun-ci", message: "couldn't collect the evidence: #{message}" }])
      end

      # The evidence of a row an older fun-ci kept: the output's tail, and the
      # failures its stage's reports named.
      def self.legacy(tail:, failures:)
        new(chosen: [], facts: [], failures: failures.map { |failure| failure.merge(extractor: "test-reports") },
            excerpts: tail ? [tail_excerpt(tail)] : [], problems: [])
      end

      # The output's last lines as output-tail kept them, or nil.
      def tail
        excerpt = excerpts.find { |candidate| candidate[:extractor] == "output-tail" }
        excerpt && excerpt[:lines].map { |line| "#{line}\n" }.join
      end

      def self.tail_excerpt(tail)
        { title: TAIL_TITLE, location: "output", lines: tail.lines(chomp: true), extractor: "output-tail" }
      end
      private_class_method :tail_excerpt, :credited
    end
  end
end
