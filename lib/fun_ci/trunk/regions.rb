# frozen_string_literal: true

module FunCi
  module Trunk
    # The conflicted regions of a file as a merge leaves it (architecture.md, Checking against the trunk,
    # why REV trunk): each conflict from its <<<<<<< line to its >>>>>>> line,
    # with `around` lines either side, regions that touch joined into one.
    module Regions
      # Lines first to last, as [number, text] pairs, numbered from 1.
      Region = Data.define(:first, :last, :lines)
      AROUND = 3

      def self.of(text, around: AROUND)
        lines = text.lines(chomp: true)
        spans = conflicts(lines).map { |from, to| [[from - around, 0].max, [to + around, lines.size - 1].min] }
        joined(spans).map { |from, to| region(lines, from, to) }
      end

      def self.region(lines, from, to)
        Region.new(first: from + 1, last: to + 1, lines: (from..to).map { |index| [index + 1, lines[index]] })
      end

      # [index of <<<<<<<, index of >>>>>>>] for each conflict.
      def self.conflicts(lines)
        marked = ->(marker) { lines.each_index.select { |index| lines[index].start_with?(marker) } }
        marked.call("<<<<<<<").zip(marked.call(">>>>>>>"))
      end

      def self.joined(spans)
        spans.each_with_object([]) do |(from, to), joined|
          touching = joined.any? && from <= joined.last[1] + 1
          touching ? joined[-1] = [joined.last[0], [joined.last[1], to].max] : joined << [from, to]
        end
      end
      private_class_method :region, :conflicts, :joined
    end
  end
end
