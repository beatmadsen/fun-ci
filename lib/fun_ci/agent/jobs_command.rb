# frozen_string_literal: true

require "json"
require_relative "command_support"
require_relative "jobs_text"
require_relative "job_why"
require_relative "job_json"

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
  end
end
