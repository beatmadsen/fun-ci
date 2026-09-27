# frozen_string_literal: true

require_relative "patterns"
require_relative "log_record"

module FunCi
  module Evidence
    # Checks the options of an entry for a built-in against what the built-in
    # declares it takes (OPTIONS, each with a kind, and REQUIRED), and
    # answers the first mistake, or nil.
    module OptionCheck
      KINDS = {
        patterns: lambda { |value|
          next "must be a list of patterns" unless Array(value).all?(String)

          Array(value).lazy.filter_map { |source| Patterns.mistake(source) }.first
        },
        count: ->(value) { "must be a whole number, not #{value.inspect}" unless value.is_a?(Integer) && value >= 0 },
        path: ->(value) { "must be a path, not #{value.inspect}" unless value.is_a?(String) && !value.empty? },
        globs: ->(value) { "must be a list of paths, not #{value.inspect}" unless Array(value).all?(String) },
        word: ->(value) { "must be a word, not #{value.inspect}" unless value.is_a?(String) },
        level: lambda { |value|
          "must be one of trace, debug, info, warn, error or fatal, not #{value.inspect}" unless LogRecord.rank(value)
        },
        fields: lambda { |value|
          "must map time, level, logger, message and stack to field names" unless mapping_of_strings?(value)
        },
        levels: ->(value) { "must map each level's number to its name" unless mapping_of_strings?(value) }
      }.freeze

      def self.mapping_of_strings?(value) = value.is_a?(Hash) && value.values.all?(String)

      def self.mistake(name, built_in, options)
        unknown = options.keys.find { |key| !built_in::OPTIONS.key?(key) }
        return "#{name} doesn't take '#{unknown}'" if unknown

        missing = built_in::REQUIRED.find { |key| !options.key?(key) }
        return "#{name} needs '#{missing}'" if missing

        kinds(name, built_in, options)
      end

      def self.kinds(name, built_in, options)
        options.each do |key, value|
          problem = KINDS.fetch(built_in::OPTIONS.fetch(key)).call(value)
          return "#{name}: '#{key}' #{problem}" if problem
        end
        nil
      end
      private_class_method :kinds
    end
  end
end
