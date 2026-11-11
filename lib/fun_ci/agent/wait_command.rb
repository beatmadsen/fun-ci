# frozen_string_literal: true

require_relative "command_support"
require_relative "output"
require_relative "waiting"
require_relative "onward"

module FunCi
  module Agent
    # `fun-ci wait [REV] [--need LEVEL] [--within DURATION] [--follow-branch] [--json]`
    # (acceptance-tests.md, AT-9.9 to AT-9.12, AT-9.21).
    class WaitCommand
      include CommandSupport

      NAME = "wait"
      # How long a commit may go without a run before `wait` starts one; the
      # post-commit hook's run for a commit just made turns up well within it.
      GRACE_SECONDS = 5
      # The answer when no run turned up and the project can't start one.
      NOT_SET_UP = Data.define(:verdict, :superseded_by).new(verdict: :unknown, superseded_by: nil)
      # A superseded commit started again: the report on its superseded run,
      # that run's id, and when it was started again.
      Again = Data.define(:report, :run_id, :since)

      def initialize(context)
        @context = context
      end

      def run(args)
        options = Options.parse(args, takes: %i[need json within follow_branch trunk])
        sha = resolve(options.rev)
        output = output(options)
        answer(sha, wait_for(sha, options, deadline(options), output), output)
      rescue Options::Invalid => e
        usage(e.message)
      end

      private

      def deadline(options) = options.within && (@context.clock.now + options.within)

      def wait_for(sha, options, deadline, output)
        report = Waiting.new(@context.clock, deadline: deadline) { poll(sha, options) }.until_decided
        step = Onward.decide(report, follow_branch: options.follow_branch, ran_again: !@again.nil?)
        onward = carry_out(step, sha, report, output)
        onward ? wait_for(onward, options, deadline, output) : report
      end

      # The commit to wait on next, having done what `step` says (Onward).
      def carry_out(step, sha, report, output)
        case step
        in :follow then follow(sha, report, output)
        in :run_again then run_again(sha, report, output)
        in :stop then nil
        end
      end

      def follow(sha, report, output)
        output.following(sha, report)
        report.superseded_by
      end

      # The commit, once its pipeline is started again; nil when it can't be.
      def run_again(sha, report, output)
        @again = Again.new(report: report, run_id: reports.latest_id(sha), since: @context.clock.now)
        output.running_again(sha, report)
        sha if @context.pipeline.start(sha, report.branch)
      end

      def answer(sha, report, output)
        return output.no_run_yet(sha) unless report
        return output.not_set_up(sha) if report.equal?(NOT_SET_UP)

        output.report(report)
        ExitCode::FOR.fetch(report.verdict)
      end

      # A waiter keeps its run from being superseded, unless it follows the branch to the newer commit.
      def poll(sha, options)
        @context.pipeline.watch(@context.db)
        reports.mark_waited(sha, @context.clock.now) unless options.follow_branch
        return run_again_report(sha, options) if @again

        report_for(sha, options) || start_after_grace(sha)
      end

      # The commit's new run once it turns up; the superseded run's report once it hasn't in time.
      def run_again_report(sha, options)
        return report_for(sha, options) if reports.latest_id(sha) != @again.run_id

        @again.report if @context.clock.now - @again.since >= GRACE_SECONDS
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
