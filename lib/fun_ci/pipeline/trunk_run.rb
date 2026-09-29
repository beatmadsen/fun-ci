# frozen_string_literal: true

require_relative "../trunk/check"
require_relative "../trunk/checker"

module FunCi
  module Pipeline
    # A run's check against the trunk (docs/trunk-conflicts.md, Inside the
    # trigger). It begins before the stages, where the database may be used
    # (claiming a fetch, recording its process, reading the other branches'
    # heads); finishes in a thread beside them, which touches no database,
    # since the slow suite's fork closes the recorder, checking the other
    # heads too when the trunk has moved; and is recorded once the stages are
    # done, through whichever recorder the run holds then. Whatever goes wrong
    # is recorded as an unknown check rather than raised into the run.
    class TrunkRun
      Result = Trunk::Checker::Result
      # What the thread found: the run's own result, and the other heads' checks.
      Found = Data.define(:result, :rechecks)

      # For a project that checks no trunk.
      class Skipped
        def finish(_recorder) = nil
        def notice = nil
      end

      # trunk: begins a check (#start(sha, fetches), nil for none), finishes it
      # (#finish(pending)) and checks other heads against a tip (#recheck(heads, tip)).
      def self.start(trunk, sha, recorder)
        pending = trunk.start(sha, recorder.trunk_fetches) { |pid| recorder.trunk_fetch_process(pid) }
        return Skipped.new unless pending

        recorder.trunk_check_started
        heads = recorder.trunk_heads(except: sha)
        new(Thread.new { found(trunk, pending, sha, heads) }, trunk.notice(pending))
      rescue StandardError => e
        new(Thread.new { Found.new(result: failed(sha, e), rechecks: []) })
      end

      def self.found(trunk, pending, sha, heads)
        rechecked(trunk, heads, Found.new(result: finished(trunk, pending, sha), rechecks: []))
      end

      def self.finished(trunk, pending, sha)
        trunk.finish(pending)
      rescue StandardError => e
        failed(sha, e)
      end

      # A recheck that goes wrong costs the other heads a fresher check, never the run its own.
      def self.rechecked(trunk, heads, found)
        tip = found.result.check&.tip
        tip ? found.with(rechecks: trunk.recheck(heads, tip)) : found
      rescue StandardError
        found
      end

      def self.failed(sha, error)
        check = Trunk::Check.new(commit: sha, tip: nil,
                                 merge: Trunk::Merge.unknown("the check failed: #{error.message}"))
        Result.new(check: check, fetched: nil)
      end
      private_class_method :found, :finished, :rechecked, :failed

      attr_reader :notice

      # notice: what to tell the developer of a first fetch, or nil.
      def initialize(thread, notice = nil)
        @thread = thread
        @notice = notice
      end

      def finish(recorder)
        found = @thread.value
        result = found.result
        recorder.trunk_fetched(result.fetched, result.check&.tip) if result.fetched
        [result.check, *found.rechecks].compact.each { |check| recorder.trunk_checked(check) }
      end
    end
  end
end
