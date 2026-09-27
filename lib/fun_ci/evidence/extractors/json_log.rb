# frozen_string_literal: true

require_relative "../findings"
require_relative "../source"
require_relative "../line_scan"
require_relative "../log_record"

module FunCi
  module Evidence
    module Extractors
      # `json-log`: the JSON log lines of the output, or of a file, at or
      # above `level` (warn by default), each as one line (time, level,
      # logger, message) followed by its stack trace. A preset names a
      # logging setup's `fields`, such as logstash's.
      class JsonLog
        OPTIONS = { "path" => :path, "level" => :level, "fields" => :fields, "levels" => :levels }.freeze
        REQUIRED = %w[fields].freeze

        def initialize(options)
          @options = options
        end

        def extract(context)
          source = Source.for(context, @options["path"])
          kept = []
          truncated = LineScan.cut_short?(source.lines, context.deadline) { |line, index| keep(kept, line, index) }
          Findings.new(excerpts: kept.empty? ? [] : [excerpt(source, kept, truncated)])
        end

        private

        def keep(kept, line, index)
          record = LogRecord.parse(line, @options["fields"], @options.fetch("levels", {}))
          kept << [index, record.lines] if record&.at_least?(LogRecord.rank(@options.fetch("level", "warn")))
        end

        def excerpt(source, kept, truncated)
          { title: "Log records at #{@options.fetch("level", "warn")} or above",
            location: source.location(kept.first.first, kept.last.first), lines: kept.flat_map(&:last),
            truncated: truncated }
        end
      end
    end
  end
end
