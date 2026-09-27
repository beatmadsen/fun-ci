# frozen_string_literal: true

module FunCi
  module Agent
    # A stage's evidence as text: its facts, its failures, each with its whole
    # message, each excerpt under its title, each naming the extractor that
    # found it, then the problems extractors had.
    module EvidenceText
      def self.lines(document)
        facts(document.facts) + failures(document.failures) +
          document.excerpts.flat_map { |excerpt| excerpt(excerpt) } + problems(document.problems)
      end

      def self.facts(facts)
        facts.empty? ? [] : ["", "Facts:", *facts.map { |fact| "  #{fact[:name]}: #{fact[:value]}" }]
      end

      def self.problems(problems)
        return [] if problems.empty?

        lines = problems.map { |problem| "  #{problem[:extractor]}: #{problem[:message]}" }
        ["", "Problems collecting the evidence:", *lines]
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
        place = excerpt[:location] == "output" ? "" : " (#{excerpt[:location]})"
        ["", "#{excerpt[:title]}#{place}, from #{excerpt[:extractor]}:", *excerpt[:lines].map { |line| "  #{line}" }]
      end
      private_class_method :facts, :problems, :failures, :failure, :excerpt
    end
  end
end
