# frozen_string_literal: true

require "json"

module FunCi
  module Evidence
    # One JSON log line, read through the field names a logging setup uses
    # (`fields`: time, level, logger, message, stack), each a key or a dotted
    # path, and `levels`, the names of numeric levels.
    class LogRecord
      RANKS = %w[trace debug info warn error fatal].freeze
      ALIASES = { "warning" => "warn", "critical" => "fatal", "err" => "error", "panic" => "fatal",
                  "verbose" => "debug" }.freeze

      # The record on a line, or nil for one that isn't a JSON object.
      def self.parse(line, fields, levels)
        return nil unless line.lstrip.start_with?("{")

        parsed = JSON.parse(line)
        parsed.is_a?(Hash) ? new(parsed, fields, levels) : nil
      rescue JSON::ParserError
        nil
      end

      def self.rank(level) = RANKS.index(ALIASES.fetch(level.to_s.downcase, level.to_s.downcase))

      def initialize(parsed, fields, levels)
        @parsed = parsed
        @fields = fields
        @levels = levels
      end

      def level = LogRecord.rank(@levels.fetch(field("level").to_s, field("level")))
      def at_least?(rank) = !level.nil? && level >= rank

      def lines
        logger = field("logger")
        head = [field("time"), RANKS[level].upcase, logger && "#{logger}:", field("message")].compact.join(" ")
        [head, *stack.map { |line| "  #{line}" }]
      end

      private

      def stack
        trace = field("stack")
        trace.is_a?(Array) ? trace.map(&:to_s) : trace.to_s.lines(chomp: true)
      end

      def field(name)
        key = @fields[name]
        return nil unless key

        @parsed.key?(key) ? @parsed[key] : @parsed.dig(*key.split("."))
      rescue TypeError
        nil
      end
    end
  end
end
