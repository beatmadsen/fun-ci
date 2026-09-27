# frozen_string_literal: true

require_relative "test_report"

module FunCi
  module Pipeline
    # The failures in the test reports in a directory: JUnit XML (*.xml) and
    # fun-ci's JSON (*.json), in name order. A report that can't be read is
    # skipped.
    module ReportReader
      READERS = { ".xml" => TestReport.method(:junit), ".json" => TestReport.method(:json) }.freeze

      def self.failures(dir)
        Dir.children(dir).sort.flat_map { |name| read(File.join(dir, name)) || [] }
      end

      def self.read(path)
        reader = READERS[File.extname(path)]
        reader&.call(File.read(path))
      end
      private_class_method :read
    end
  end
end
