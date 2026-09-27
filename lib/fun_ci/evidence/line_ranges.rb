# frozen_string_literal: true

module FunCi
  module Evidence
    # The runs of lines around chosen lines: `context` lines either side of
    # each, within 0...size, joined where they meet.
    module LineRanges
      def self.around(indexes, context, size)
        indexes.map { |index| [index - context, 0].max..[index + context, size - 1].min }
               .each_with_object([]) { |range, joined| join(joined, range) }
      end

      def self.join(joined, range)
        return joined << range if joined.empty? || joined.last.last + 1 < range.first

        joined[-1] = joined.last.first..[joined.last.last, range.last].max
      end
      private_class_method :join
    end
  end
end
