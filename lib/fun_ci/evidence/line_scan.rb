# frozen_string_literal: true

module FunCi
  module Evidence
    # Walks lines for a built-in extractor, checking the deadline every
    # CHECK_EVERY lines, since a built-in runs in fun-ci's own process and
    # can't be killed.
    module LineScan
      CHECK_EVERY = 1000

      # Yields each line and its index; answers whether the deadline stopped it first.
      def self.cut_short?(lines, deadline)
        lines.each_with_index do |line, index|
          return true if (index % CHECK_EVERY).zero? && deadline.passed?

          yield line, index
        end
        false
      end
    end
  end
end
