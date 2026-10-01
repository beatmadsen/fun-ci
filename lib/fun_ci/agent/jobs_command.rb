# frozen_string_literal: true

require "json"
require_relative "command_support"
require_relative "jobs_text"
require_relative "job_why"

module FunCi
  module Agent
    # `fun-ci jobs [--json]` (acceptance-tests.md, AT-13.22): the project's
    # daily and weekly jobs and how each stands.
    class JobsCommand
      include CommandSupport

      NAME = "jobs"
      SCHEMA = 1

      def initialize(context)
        @context = context
      end

      def run(args)
        options = Options.parse(args, takes: %i[json])
        say(job_reports.all, options.json)
        0
      rescue Options::Invalid => e
        usage(e.message)
      end

      private

      def say(reports, json)
        return out.puts(JSON.generate(schema: SCHEMA, jobs: reports.map { |report| JobJson.document(report) })) if json
        return out.puts("fun-ci: #{JobWhy::NO_JOBS}") if reports.empty?

        JobsText.lines(reports, @context.clock.now).each { |line| out.puts line }
      end

      def out = @context.io.stdout
    end

    # One job as `jobs --json` gives it. Fields once published keep their names.
    module JobJson
      def self.document(report)
        stage = report.stage
        { name: report.name, cadence: report.cadence, state: report.state,
          commit: stage && { sha: report.sha, branch: report.branch }, seconds: stage&.seconds,
          started_at: report.started_at&.utc&.iso8601, due_at: report.due_at&.utc&.iso8601 }
      end
    end
  end
end
