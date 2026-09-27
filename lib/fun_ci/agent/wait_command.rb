# frozen_string_literal: true

require_relative "command_support"
require_relative "output"
require_relative "waiting"

module FunCi
  module Agent
    # `fun-ci wait [REV] [--need LEVEL] [--within DURATION] [--follow-branch] [--json]`
    # (acceptance-tests.md, AT-9.9 to AT-9.12).
    class WaitCommand
      include CommandSupport

      NAME = "wait"
      # How long a commit may go without a run before `wait` starts one; the
      # post-commit hook's run for a commit just made turns up well within it.
      GRACE_SECONDS = 5
      # The answer when no run turned up and the project can't start one.
      NOT_SET_UP = Data.define(:verdict).new(verdict: :unknown)

      def initialize(context)
        @context = context
      end

      def run(args)
        options = Options.parse(args, takes: %i[need json within follow_branch])
        sha = resolve(options.rev)
        output = Output.new(@context.io.stdout, json: options.json)
        answer(sha, wait_for(sha, options, deadline(options), output), output)
      rescue Options::Invalid => e
        usage(e.message)
      end

      private

      def deadline(options) = options.within && (@context.clock.now + options.within)

      # Follows a superseded run on to the commit that superseded it, when asked to.
      def wait_for(sha, options, deadline, output)
        report = Waiting.new(@context.clock, deadline: deadline) { poll(sha, options.need) }.until_decided
        return report unless options.follow_branch && report&.superseded_by

        output.following(sha, report)
        wait_for(report.superseded_by, options, deadline, output)
      end

      def answer(sha, report, output)
        return output.no_run_yet(sha) unless report
        return output.not_set_up(sha) if report.equal?(NOT_SET_UP)

        output.report(report)
        ExitCode::FOR.fetch(report.verdict)
      end

      def poll(sha, need)
        @context.pipeline.watch(@context.db)
        reports.mark_waited(sha, @context.clock.now)
        reports.for(sha, need) || start_after_grace(sha)
      end

      # Nil while waiting for a run; NOT_SET_UP once one can't be started.
      def start_after_grace(sha)
        @missing_since ||= @context.clock.now
        return if @started || @context.clock.now - @missing_since < GRACE_SECONDS

        @started = true
        @context.pipeline.start(sha, @context.git.branch) ? nil : NOT_SET_UP
      end
    end
  end
end
