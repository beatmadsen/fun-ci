# frozen_string_literal: true

require_relative "../findings"
require_relative "../source"
require_relative "../line_scan"
require_relative "../patterns"
require_relative "../line_ranges"

module FunCi
  module Evidence
    module Extractors
      # `grep`: the lines of the output, or of a file, that match any of
      # `patterns`, with `context` lines around each; matches whose context
      # meets are one excerpt.
      class Grep
        OPTIONS = { "patterns" => :patterns, "context" => :count, "path" => :path, "title" => :word }.freeze
        REQUIRED = %w[patterns].freeze

        def initialize(options)
          @options = options
        end

        def extract(context) = found_in(Source.for(context, @options["path"]), context.deadline)

        def found_in(source, deadline)
          hits, truncated = matches(source.lines, deadline)
          ranges = LineRanges.around(hits, @options.fetch("context", 0), source.lines.size)
          Findings.new(excerpts: ranges.map { |range| excerpt(source, range, truncated) })
        end

        private

        def matches(lines, deadline)
          patterns = Patterns.compile(@options["patterns"])
          hits = []
          truncated = LineScan.cut_short?(lines, deadline) do |line, index|
            hits << index if patterns.any? { |pattern| pattern.match?(line) }
          end
          [hits, truncated]
        end

        def excerpt(source, range, truncated)
          { title: @options.fetch("title") { "Lines matching #{Array(@options["patterns"]).join(" or ")}" },
            location: source.location(range.first, range.last), lines: source.lines[range], truncated: truncated }
        end
      end
    end
  end
end
