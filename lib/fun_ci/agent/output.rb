# frozen_string_literal: true

require "json"
require_relative "status_text"
require_relative "status_json"
require_relative "exit_code"

module FunCi
  module Agent
    # Prints what an agent command found, as text or, with --json, as JSON.
    class Output
      def initialize(stdout, json:)
        @stdout = stdout
        @json = json
      end

      def report(report)
        @json ? print_json(StatusJson.document(report)) : print_lines(StatusText.lines(report))
      end

      # Says the commit has no run, and answers the exit code for that.
      def unknown(sha)
        @json ? print_json(StatusJson.unknown(sha)) : print_lines(["fun-ci: no run for #{sha[0, 7]} in this project."])
        ExitCode::FOR.fetch(:unknown)
      end

      private

      def print_json(document) = @stdout.puts(JSON.generate(document))
      def print_lines(lines) = lines.each { |line| @stdout.puts line }
    end
  end
end
