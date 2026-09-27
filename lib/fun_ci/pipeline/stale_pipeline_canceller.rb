# frozen_string_literal: true

require_relative "../persistence/active_runs"
require_relative "run_canceller"

module FunCi
  module Pipeline
    # A newer commit on a branch cancels every run still going for an older
    # one, unless an agent is waiting on it: its processes are stopped and it
    # is recorded cancelled (acceptance-tests.md, AT-1.6, AT-9.12).
    class StalePipelineCanceller
      def initialize(db:, branch:, stdout:, run_canceller: RunCanceller.new)
        @db = db
        @branch = branch
        @stdout = stdout
        @run_canceller = run_canceller
      end

      # How long an agent's last poll keeps a run it waits on from being cancelled.
      WAITED_ON_SECONDS = 10

      def cancel(new_commit_hash:)
        waited_before = (Time.now - WAITED_ON_SECONDS).utc.iso8601
        Persistence::ActiveRuns.cancellable(@db, @branch, new_commit: new_commit_hash, waited_before: waited_before)
                               .each { |run| cancel_run(run, new_commit_hash) }
      end

      private

      def cancel_run(run, new_commit_hash)
        @run_canceller.cancel(@db, run)
        @stdout.puts "Cancelled stale pipeline for #{run.commit_hash}. Starting fresh for #{new_commit_hash}."
      end
    end
  end
end
