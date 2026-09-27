# frozen_string_literal: true

module FunCi
  module Evidence
    # The lines an extractor reads, and the name of where they came from: the
    # output, or a file in the worktree. Colour codes are stripped and bytes
    # that aren't UTF-8 replaced, so patterns match what a person would read.
    Source = Data.define(:name, :lines)

    class Source
      COLOUR = /\e\[[0-9;?]*[A-Za-z]/

      def self.for(context, path)
        return of("output", context.output) unless path

        of(path, context.worktree.read(path))
      end

      def self.of(name, text)
        new(name: name, lines: text.dup.force_encoding(Encoding::UTF_8).scrub("?").gsub(COLOUR, "").lines(chomp: true))
      end

      # Where lines first..last (counted from 0) are, as `name:first-last` counted from 1.
      def location(first, last) = first == last ? "#{name}:#{first + 1}" : "#{name}:#{first + 1}-#{last + 1}"
    end
  end
end
