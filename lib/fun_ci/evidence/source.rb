# frozen_string_literal: true

module FunCi
  module Evidence
    # The lines an extractor reads, and the name of where they came from: the
    # output, or a file in the worktree. Colour codes are stripped and bytes
    # that aren't UTF-8 replaced, so patterns match what a person would read.
    # `skipped` is how many lines of the file came before these.
    Source = Data.define(:name, :lines, :skipped)

    class Source
      COLOUR = /\e\[[0-9;?]*[A-Za-z]/

      def self.for(context, path)
        return of("output", context.output) unless path

        of(path, context.worktree.read(path))
      end

      def self.of(name, text, skipped: 0)
        lines = text.dup.force_encoding(Encoding::UTF_8).scrub("?").gsub(COLOUR, "").lines(chomp: true)
        new(name: name, lines: lines, skipped: skipped)
      end

      # Where lines first..last (counted from 0) are, as `name:first-last`
      # counted from 1 in the whole file.
      def location(first, last)
        from = first + skipped + 1
        to = last + skipped + 1
        from == to ? "#{name}:#{from}" : "#{name}:#{from}-#{to}"
      end
    end
  end
end
