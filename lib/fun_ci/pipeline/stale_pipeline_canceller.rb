# frozen_string_literal: true

require_relative "../persistence/active_runs"
require_relative "run_canceller"

module FunCi
  module Pipeline
    # A newer commit on a branch cancels every run still going for an older
    # one: its processes are stopped and it is recorded cancelled.
    class StalePipelineCanceller
      def initialize(db:, branch:, stdout:, run_canceller: RunCanceller.new)
        @db = db
        @branch = branch
        @stdout = stdout
        @run_canceller = run_canceller
      end

      def cancel(new_commit_hash:)
        Persistence::ActiveRuns.on_branch(@db, @branch).each { |run| cancel_run(run, new_commit_hash) }
      end

      private

      def cancel_run(run, new_commit_hash)
        @run_canceller.stop(run)
        Persistence::ActiveRuns.cancelled(@db, run)
        @stdout.puts "Cancelled stale pipeline for #{run.commit_hash}. Starting fresh for #{new_commit_hash}."
      end
    end
  end
end
