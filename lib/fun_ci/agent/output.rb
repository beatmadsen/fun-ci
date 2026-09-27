# frozen_string_literal: true

require "json"
require_relative "status_text"
require_relative "status_json"
require_relative "runs_text"
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

      # Says the commit has no run yet, which leaves it undecided.
      def no_run_yet(sha)
        if @json
          print_json(StatusJson.unknown(sha).merge(verdict: "undecided"))
        else
          print_lines(["fun-ci: no run for #{sha[0, 7]} yet."])
        end
        ExitCode::FOR.fetch(:undecided)
      end

      # Says the wait moves on to the commit that superseded `sha`; JSON has only the answer.
      def following(sha, report)
        return if @json

        @stdout.puts "fun-ci: #{sha[0, 7]} was superseded; following #{report.branch} to #{report.superseded_by[0, 7]}."
      end

      # entries: [[report, age in words], ...], newest first.
      def runs(entries)
        return print_json(entries.map { |report, _| StatusJson.document(report) }) if @json

        print_lines(RunsText.lines(entries))
      end

      private

      def print_json(document) = @stdout.puts(JSON.generate(document))
      def print_lines(lines) = lines.each { |line| @stdout.puts line }
    end
  end
end
