# frozen_string_literal: true

require_relative "../findings"
require_relative "../source"
require_relative "../line_scan"
require_relative "../patterns"
require_relative "../section_walk"

module FunCi
  module Evidence
    module Extractors
      # `section`: the lines of the output, or of a file, from a line that
      # matches any of `start` up to one that matches any of `end` (or the
      # last line), each section at most `lines` long. A preset names a tool's
      # sections, such as rspec's failures.
      class Section
        OPTIONS = { "start" => :patterns, "end" => :patterns, "path" => :path, "lines" => :count,
                    "title" => :word }.freeze
        REQUIRED = %w[start].freeze
        LINES = 200

        def initialize(options)
          @options = options
        end

        def extract(context) = found_in(Source.for(context, @options["path"]), context.deadline)

        def found_in(source, deadline)
          walk = new_walk
          truncated = LineScan.cut_short?(source.lines, deadline) { |line, index| walk.step(line, index) }
          Findings.new(excerpts: walk.finish(source.lines).map { |found| excerpt(source, found, truncated) })
        end

        private

        def new_walk
          SectionWalk.new(Patterns.compile(@options["start"]), Patterns.compile(@options["end"]),
                          @options.fetch("lines", LINES))
        end

        def excerpt(source, found, truncated)
          { title: @options.fetch("title") { "Lines from #{Array(@options["start"]).join(" or ")}" },
            location: source.location(found.first, found.last), lines: source.lines[found.first..found.last],
            truncated: truncated || found.cut }
        end
      end
    end
  end
end
