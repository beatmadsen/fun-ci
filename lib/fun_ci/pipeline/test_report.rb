# frozen_string_literal: true

require "rexml/document"

module FunCi
  module Pipeline
    # The failures a JUnit XML report names (acceptance-tests.md, AT-9.7),
    # each as { file:, line:, test:, message: }, with output: when the failure
    # kept its own (AT-10.14), its last 4 KB; nil for a report that can't be
    # read.
    module TestReport
      OUTPUT_BYTES = 4096

      def self.junit(xml)
        REXML::XPath.match(REXML::Document.new(xml), "//testcase[failure or error]").map { |test| junit_failure(test) }
      rescue REXML::ParseException
        nil
      end

      def self.junit_failure(test)
        with_output({ file: test.attributes["file"], line: test.attributes["line"]&.to_i, test: junit_name(test),
                      message: junit_message(test.elements["failure"] || test.elements["error"]) },
                    junit_output(test))
      end

      # The failure's text, or its message attribute when it has none.
      def self.junit_message(problem)
        text = problem.text.to_s.strip
        text.empty? ? problem.attributes["message"].to_s : text
      end

      def self.junit_name(test)
        [test.attributes["classname"], test.attributes["name"]].compact.join("#")
      end

      def self.junit_output(test)
        %w[system-out system-err].filter_map { |name| test.elements[name]&.text&.strip }.reject(&:empty?).join("\n")
      end

      def self.with_output(failure, output)
        return failure if output.empty?

        failure.merge(output: output.byteslice([output.bytesize - OUTPUT_BYTES, 0].max..).scrub(""))
      end
      private_class_method :junit_failure, :junit_message, :junit_name, :junit_output, :with_output
    end
  end
end
