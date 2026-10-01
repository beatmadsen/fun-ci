# frozen_string_literal: true

require_relative "command_support"
require_relative "output"

module FunCi
  module Agent
    # `fun-ci status [REV] [--need LEVEL] [--json]` (acceptance-tests.md,
    # AT-9.2): the commit's run, and the jobs whose latest run tested it (AT-13.24).
    class StatusCommand
      include CommandSupport

      NAME = "status"

      def initialize(context)
        @context = context
      end

      def run(args)
        options = Options.parse(args, takes: %i[need json trunk])
        sha = resolve(options.rev)
        answer(sha, report_for(sha, options), output(options))
      rescue Options::Invalid => e
        usage(e.message)
      end

      private

      def answer(sha, report, output)
        return output.unknown(sha) unless report

        output.report(report, jobs: job_reports.on_commit(sha))
        ExitCode::FOR.fetch(report.verdict)
      end
    end
  end
end
