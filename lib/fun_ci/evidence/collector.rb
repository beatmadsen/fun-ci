# frozen_string_literal: true

require_relative "sources"
require_relative "document"
require_relative "masking"
require_relative "../persistence/output_tail"

module FunCi
  module Evidence
    # Picks out what fun-ci keeps about a stage that failed, from its output
    # and its sources, and masks it before anyone keeps it.
    class Collector
      def initialize(sources)
        @sources = sources
      end

      def collect(output)
        Document.legacy(tail: Persistence::OutputTail.of(output, mask: masking.method(:mask)),
                        failures: @sources.reports.failures.map { |failure| masked_failure(failure, masking) })
      end

      # The raw output, masked as the evidence is.
      def masked(output) = masking.mask(output)

      private

      def masking = Masking.new(@sources.environment)

      def masked_failure(failure, masking)
        failure.transform_values { |value| value.is_a?(String) ? masking.mask(value) : value }
      end
    end
  end
end
