# frozen_string_literal: true

module FunCi
  module Agent
    # A stage's evidence as text: its failures, each with its whole message,
    # then each excerpt under its title, each naming the extractor that found it.
    module EvidenceText
      def self.lines(document)
        failures(document.failures) + document.excerpts.flat_map { |excerpt| excerpt(excerpt) }
      end

      def self.failures(failures)
        failures.group_by { |failure| failure[:extractor] }.flat_map do |extractor, found|
          ["", "Failures, from #{extractor}:", *found.flat_map { |failure| failure(failure) }]
        end
      end

      def self.failure(failure)
        place = failure[:file] ? "#{failure[:file]}:#{failure[:line]}  #{failure[:test]}" : failure[:test]
        ["  #{place}", *failure[:message].to_s.lines(chomp: true).map { |line| "    #{line}" }]
      end

      def self.excerpt(excerpt)
        ["", "#{excerpt[:title]}, from #{excerpt[:extractor]}:", *excerpt[:lines].map { |line| "  #{line}" }]
      end
      private_class_method :failures, :failure, :excerpt
    end
  end
end
