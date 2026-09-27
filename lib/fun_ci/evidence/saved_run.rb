# frozen_string_literal: true

require "fileutils"
require_relative "../pipeline/report_reader"

module FunCi
  module Evidence
    # A failed run's stage directory, stood in for by what `fun-ci extract`
    # is given: the reports in a directory, if one is named, and a scratch
    # directory for what a project's command reads and writes.
    class SavedRun
      def initialize(reports, scratch)
        @reports = reports
        @scratch = scratch
      end

      attr_reader :scratch

      def failures = @reports ? Pipeline::ReportReader.failures(@reports) : []
      def reports_path = @reports || File.join(@scratch, "reports")
      def env = { "FUN_CI_REPORT" => reports_path }

      def output_file(text)
        File.join(@scratch, "output.log").tap { |file| File.binwrite(file, text) }
      end
    end
  end
end
