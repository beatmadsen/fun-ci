# frozen_string_literal: true

require_relative "patterns"

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
        word: ->(value) { "must be a word, not #{value.inspect}" unless value.is_a?(String) }
      }.freeze

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
