# frozen_string_literal: true

require "json"
require_relative "job_report"
require_relative "job_why_text"
require_relative "job_why_json"
require_relative "exit_code"
require_relative "options"

module FunCi
  module Agent
    # `fun-ci why --job NAME [--json] [--raw]` (acceptance-tests.md, AT-13.21):
    # everything kept about the job's latest run, exiting as `why` does for a
    # stage in the same state; a job that never ran has no verdict.
    class JobWhy
      NO_JOBS = "this project has no daily or weekly jobs; put their scripts in .fun-ci/daily/ or .fun-ci/weekly/"

      def initialize(context, jobs)
        @context = context
        @jobs = jobs
      end

      # Raises Options::Invalid for a name that is no job of the project.
      def answer(options)
        report = @jobs.named(options.job) || raise(Options::Invalid, no_job(options.job))
        return never_ran(report, options.json) unless report.stage

        options.raw ? raw(report) : say(report, options.json)
        ExitCode::FOR.fetch(report.verdict)
      end

      private

      def say(report, json) = json ? print_json(report) : print_lines(JobWhyText.lines(report))

      def never_ran(report, json)
        json ? print_json(report) : print_lines([JobWhyText.never_ran(report)])
        ExitCode::FOR.fetch(:unknown)
      end

      def raw(report)
        text = @jobs.raw_output(report)
        return @context.io.stdout.write(text) if text

        @context.io.stderr.puts "fun-ci why: no raw output is kept for job #{report.name}"
      end

      def no_job(name)
        names = @jobs.all.map(&:name)
        return NO_JOBS if names.empty?

        "no job '#{name}' in this project: its jobs are #{names.join(", ")}"
      end

      def print_json(report) = @context.io.stdout.puts(JSON.generate(JobWhyJson.document(report)))
      def print_lines(lines) = lines.each { |line| @context.io.stdout.puts line }
    end
  end
end
