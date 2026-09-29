# frozen_string_literal: true

require "json"

module FunCi
  module Evidence
    # How much evidence fun-ci keeps (architecture.md, "Evidence of a failed stage"): at
    # most `failures` failures, the rest counted in a fact; then, over
    # `bytes` of JSON, excerpts cut from the last backwards, then messages
    # to their first `message_lines`, each cut marked `truncated`. Facts and
    # problems are small and never cut.
    class Caps
      Limits = Data.define(:bytes, :failures, :message_lines)
      REAL = Limits.new(bytes: 262_144, failures: 100, message_lines: 50)
      # What a line costs in JSON besides its own bytes: quotes and a comma.
      LINE_COST = 3

      # How many bytes of JSON a document makes.
      JSON_SIZE = ->(document) { JSON.generate(document.to_h).bytesize }

      # size: measures a document, JSON_SIZE but where a test counts the measuring.
      def initialize(limits = REAL, size: JSON_SIZE)
        @limits = limits
        @size = size
      end

      def apply(document)
        document = shorter(few_failures(document))
        over(document).positive? ? shorter_messages(document) : document
      end

      private

      # Each pass cuts at least a line, so there are never more passes than lines.
      def shorter(document)
        document.excerpts.sum { |excerpt| excerpt[:lines].size }.times do
          break unless over(document).positive?

          document = shorter_excerpts(document)
        end
        document
      end

      def over(document) = @size.call(document) - @limits.bytes

      def few_failures(document)
        left_out = document.failures.size - @limits.failures
        return document unless left_out.positive?

        count = { name: "failures not kept", value: left_out.to_s, extractor: "fun-ci" }
        document.with(failures: document.failures.first(@limits.failures), facts: document.facts + [count])
      end

      def shorter_excerpts(document)
        excess = over(document)
        excerpts = document.excerpts.reverse.map do |excerpt|
          cut, excess = cut_lines(excerpt, excess)
          cut
        end
        document.with(excerpts: excerpts.reverse)
      end

      # The excerpt without as many of its last lines as cover `excess` bytes, and what is left of `excess`.
      def cut_lines(excerpt, excess)
        lines = excerpt[:lines].dup
        excess -= lines.pop.bytesize + LINE_COST while excess.positive? && lines.any?
        [lines.size == excerpt[:lines].size ? excerpt : excerpt.merge(lines: lines, truncated: true), excess]
      end

      def shorter_messages(document)
        document.with(failures: document.failures.map { |failure| short_message(failure) })
      end

      def short_message(failure)
        lines = failure[:message].to_s.lines
        return failure if lines.size <= @limits.message_lines

        failure.merge(message: lines.first(@limits.message_lines).join.chomp, truncated: true)
      end
    end
  end
end
