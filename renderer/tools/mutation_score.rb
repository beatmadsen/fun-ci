# frozen_string_literal: true

require "json"

module FunCi
  # `rake mutation:rust`: cargo-mutants on renderer/, judged by the share of
  # viable mutants the tests caught.
  module Mutation
    # cargo-mutants exits 0 when every mutant was caught, 2 when some were
    # missed and 3 when some timed out; the score decides those. Anything else
    # (1 usage, 4 failing baseline) means the run measured nothing.
    COMPLETED = [0, 2, 3].freeze

    def self.completed?(exit_status) = COMPLETED.include?(exit_status)

    # Counts from mutants.out/outcomes.json. Unviable mutants (ones that do not
    # build) are left out; a timed-out mutant counts as not caught.
    class Score
      def self.load(path) = new(JSON.parse(File.read(path)))

      def initialize(counts)
        @counts = counts.slice("caught", "missed", "timeout", "unviable")
      end

      def percent
        viable.zero? ? 0.0 : 100.0 * caught / viable
      end

      def passes?(threshold) = viable.positive? && percent >= threshold

      def summary
        format("caught %<caught>d of %<viable>d viable mutants (%<percent>.1f%%): " \
               "missed %<missed>d, timeout %<timeout>d, unviable %<unviable>d",
               caught: caught, viable: viable, percent: percent, missed: count("missed"),
               timeout: count("timeout"), unviable: count("unviable"))
      end

      private

      def caught = count("caught")

      def viable = caught + count("missed") + count("timeout")

      def count(key) = @counts.fetch(key, 0)
    end
  end
end
