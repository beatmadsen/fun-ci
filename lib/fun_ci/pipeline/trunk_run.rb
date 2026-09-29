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
      # trunk: answers #check(sha), a Trunk::Check or nil for a project that checks none.
      def self.start(trunk, sha) = new(Thread.new { checked(trunk, sha) })

      def self.checked(trunk, sha)
        trunk.check(sha)
      rescue StandardError => e
        Trunk::Check.new(commit: sha, tip: nil, merge: Trunk::Merge.unknown("the check failed: #{e.message}"))
      end
      private_class_method :checked

      def initialize(thread)
        @thread = thread
      end

      def finish(recorder)
        check = @thread.value
        recorder.trunk_checked(check) if check
      end
    end
  end
end
