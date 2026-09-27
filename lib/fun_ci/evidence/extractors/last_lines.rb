# frozen_string_literal: true

require_relative "../findings"

module FunCi
  module Evidence
    module Extractors
      # The last `count` lines of a source, as one excerpt.
      class LastLines
        def initialize(count)
          @count = count
        end

        def found_in(source, _deadline)
          return Findings.new if source.lines.empty?

          first = [source.lines.size - @count, 0].max
          Findings.new(excerpts: [{ title: "What the stage wrote to #{source.name}",
                                    location: source.location(first, source.lines.size - 1),
                                    lines: source.lines[first..], truncated: first.positive? }])
        end
      end
    end
  end
end
