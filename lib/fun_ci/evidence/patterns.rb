# frozen_string_literal: true

module FunCi
  module Evidence
    # Patterns a project or a preset supplies, each compiled with a timeout of
    # its own rather than the process-wide Regexp.timeout, since stages run in
    # threads side by side. The timeout bounds each match.
    module Patterns
      TIMEOUT = 1.0

      def self.compile(sources, timeout: TIMEOUT) = Array(sources).map { |source| Regexp.new(source, timeout: timeout) }

      # Why a pattern doesn't compile, or nil.
      def self.mistake(source)
        Regexp.new(source)
        nil
      rescue RegexpError => e
        "has '#{source}', which doesn't compile: #{e.message}"
      end
    end
  end
end
