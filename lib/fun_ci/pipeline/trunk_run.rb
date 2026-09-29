# frozen_string_literal: true

require_relative "../trunk/check"
require_relative "../trunk/checker"

module FunCi
  module Pipeline
    # A run's check against the trunk (docs/trunk-conflicts.md, Inside the
    # trigger). It begins before the stages, where the database may be used
    # (claiming a fetch, recording its process); finishes in a thread beside
    # them, which touches no database, since the slow suite's fork closes the
    # recorder; and is recorded once they are done, through whichever
    # recorder the run holds then. Whatever goes wrong is recorded as an
    # unknown check rather than raised into the run.
    class TrunkRun
      Result = Trunk::Checker::Result

      # trunk: begins a check (#start(sha, fetches)) and finishes it (#finish(pending)).
      def self.start(trunk, sha, recorder)
        pending = trunk.start(sha, recorder.trunk_fetches) { |pid| recorder.trunk_fetch_process(pid) }
        new(Thread.new { finished(trunk, pending, sha) })
      rescue StandardError => e
        new(Thread.new { failed(sha, e) })
      end

      def self.finished(trunk, pending, sha)
        trunk.finish(pending)
      rescue StandardError => e
        failed(sha, e)
      end

      def self.failed(sha, error)
        check = Trunk::Check.new(commit: sha, tip: nil,
                                 merge: Trunk::Merge.unknown("the check failed: #{error.message}"))
        Result.new(check: check, fetched: nil)
      end
      private_class_method :finished, :failed

      def initialize(thread)
        @thread = thread
      end

      def finish(recorder)
        result = @thread.value
        recorder.trunk_fetched(result.fetched, result.check&.tip) if result.fetched
        recorder.trunk_checked(result.check) if result.check
      end
    end
  end
end
