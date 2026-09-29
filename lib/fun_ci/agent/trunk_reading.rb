# frozen_string_literal: true

require "time"
require_relative "../persistence/trunk_checks"
require_relative "../persistence/trunk_fetches"
require_relative "../trunk/shown"

module FunCi
  module Agent
    # How a run's commit stands against the project's trunk, as recorded:
    # its latest check, how old that is, why the last fetch failed, and
    # where the trunk has moved to since, which it reads and never checks.
    class TrunkReading
      # trunk: where the trunk is now (#now_at(tip)).
      def initialize(db, project, clock, trunk)
        @checks = Persistence::TrunkChecks.new(db, project)
        @fetches = Persistence::TrunkFetches.new(db, project)
        @clock = clock
        @trunk = trunk
      end

      # A Trunk::Shown, or nil for a run that began no check.
      def for(run)
        check = @checks.latest(run[:commit_hash])
        return shown(check) if check

        started = run[:trunk_started_at]
        started && Trunk::Shown.unchecked(started: Time.parse(started), now: @clock.now)
      end

      # Checks the commit against where the trunk is now, without fetching, and keeps the check,
      # unless the project checks no trunk any more.
      def recheck(sha)
        check = @trunk.check(sha, @fetches)
        @checks.record(check, checked_at: @clock.now) if check
      end

      private

      def shown(check)
        Trunk::Shown.of(check, now: @clock.now, fetch_error: @fetches.last&.error, moved_to: moved(check))
      end

      def moved(check)
        now = check.tip && @trunk.now_at(check.tip)
        now == check.tip&.sha ? nil : now
      end
    end
  end
end
