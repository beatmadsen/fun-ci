# frozen_string_literal: true

require "json"
require "rexml/document"

module FunCi
  module Pipeline
    # The failures a stage reports (acceptance-tests.md, AT-9.7), each as
    # { file:, line:, test:, message: }, with output: when the failure kept
    # its own (AT-10.14), its last 4 KB; nil for a report that can't be read.
    # An entry of fun-ci's JSON that is no object is passed over.
    module TestReport
      OUTPUT_BYTES = 4096

      def self.junit(xml)
        REXML::XPath.match(REXML::Document.new(xml), "//testcase[failure or error]").map { |test| junit_failure(test) }
      rescue REXML::ParseException
        nil
      end

      def self.json(text)
        failures = JSON.parse(text)["failures"]
        failures.is_a?(Array) ? failures.grep(Hash).map { |failure| json_failure(failure) } : nil
      rescue JSON::ParserError, TypeError
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

      def self.json_failure(failure)
        with_output({ file: failure["file"], line: failure["line"]&.to_i, test: failure["test"],
                      message: failure["message"].to_s }, failure["output"].to_s)
      end

      def self.with_output(failure, output)
        return failure if output.empty?

        failure.merge(output: output.byteslice([output.bytesize - OUTPUT_BYTES, 0].max..).scrub(""))
      end
      private_class_method :junit_failure, :junit_message, :junit_name, :junit_output, :json_failure, :with_output
    end
  end
end
