# frozen_string_literal: true

require "fileutils"

module FunCi
  module Evidence
    # A failed run's stage directory, stood in for by what `fun-ci extract`
    # is given: a scratch directory for what a project's command reads and
    # writes.
    class SavedRun
      def initialize(scratch)
        @scratch = scratch
      end

      attr_reader :scratch

      def output_file(text)
        File.join(@scratch, "output.log").tap { |file| File.binwrite(file, text) }
      end
    end
  end
end
