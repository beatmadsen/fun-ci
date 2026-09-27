# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "test_report"

module FunCi
  module Pipeline
    # An empty directory a stage may write test reports into, named to it as
    # FUN_CI_REPORT (acceptance-tests.md, AT-9.7): JUnit XML (*.xml) and
    # fun-ci's JSON (*.json). A report that can't be read is skipped.
    class ReportDir
      READERS = { ".xml" => TestReport.method(:junit), ".json" => TestReport.method(:json) }.freeze

      def self.create = new(Dir.mktmpdir("fun-ci-report"))

      def initialize(path)
        @path = path
      end

      def env = { "FUN_CI_REPORT" => @path }

      def failures
        Dir.children(@path).sort.flat_map { |name| read(name) || [] }
      end

      def remove = FileUtils.rm_rf(@path)

      private

      def read(name)
        reader = READERS[File.extname(name)]
        reader&.call(File.read(File.join(@path, name)))
      end
    end
  end
end
