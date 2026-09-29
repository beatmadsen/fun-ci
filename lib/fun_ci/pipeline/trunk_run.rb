# frozen_string_literal: true

require_relative "../trunk/check"

module FunCi
  module Pipeline
    # A run's check against the trunk (docs/trunk-conflicts.md, Inside the
    # trigger): made in a thread beside the stages, since it needs no slot,
    # and recorded once they are done, through whichever recorder the run
    # holds then. The thread touches no database, and whatever goes wrong in
    # it is recorded as an unknown check rather than raised into the run.
    class TrunkRun
      # For a project whose trunk isn't checked.
      class Skipped
        def finish(_recorder) = nil
      end

      def self.start(trunk, sha) = trunk ? new(Thread.new { checked(trunk, sha) }) : Skipped.new

      def self.checked(trunk, sha)
        trunk.check(sha)
      rescue StandardError => e
        Trunk::Check.new(commit: sha, tip: nil, merge: Trunk::Merge.unknown("the check failed: #{e.message}"))
      end
      private_class_method :checked

      def initialize(thread)
        @thread = thread
      end

      def finish(recorder) = recorder.trunk_checked(@thread.value)
    end
  end
end
