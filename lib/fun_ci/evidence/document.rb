# frozen_string_literal: true

module FunCi
  module Evidence
    # What fun-ci kept about why a stage failed (why.md): the extractors
    # chosen and why, facts, failures, excerpts, and the problems extractors
    # had. Each item is a hash naming the extractor that found it.
    Document = Data.define(:chosen, :facts, :failures, :excerpts, :problems)

    class Document
      TAIL_TITLE = "The output's last lines"

      # The evidence of a row that kept only the output's tail and the reported failures.
      def self.legacy(tail:, failures:)
        new(chosen: [], facts: [], failures: failures.map { |failure| failure.merge(extractor: "test-reports") },
            excerpts: tail ? [tail_excerpt(tail)] : [], problems: [])
      end

      def self.tail_excerpt(tail)
        { title: TAIL_TITLE, location: "output", lines: tail.lines(chomp: true), extractor: "output-tail" }
      end
      private_class_method :tail_excerpt
    end
  end
end
