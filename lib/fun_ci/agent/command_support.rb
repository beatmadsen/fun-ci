# frozen_string_literal: true

require_relative "options"
require_relative "reports"
require_relative "exit_code"
require_relative "trunk_verdict"
require_relative "job_report"

module FunCi
  module Agent
    # What the agent commands share: the commit a revision names, the reports
    # of its runs, and refusing arguments they can't use. Expects @context and
    # a NAME constant.
    module CommandSupport
      private

      def resolve(rev)
        @context.git.resolve(rev) || raise(Options::Invalid, "git can't find the commit '#{rev}'")
      end

      # The commit's newest run, judged on the trunk too when the agent asked
      # (--trunk), checked again first when the trunk has moved since.
      def report_for(sha, options)
        report = reports.for(sha, options.need)
        return report unless options.trunk && report

        report = reports.recheck_trunk(sha).then { reports.for(sha, options.need) } if report.trunk&.moved_to
        report.with(verdict: TrunkVerdict.of(report.verdict, report.trunk))
      end

      def output(options) = Output.new(@context.io.stdout, json: options.json, trunk: options.trunk)

      def reports = @reports ||= Reports.new(@context.db, @context.git, @context.clock, @context.trunk)
      def job_reports = JobReports.new(@context.db, @context.git.toplevel, @context.clock)

      def usage(message)
        @context.io.stderr.puts "fun-ci #{self.class::NAME}: #{message}"
        ExitCode::USAGE
      end
    end
  end
end
