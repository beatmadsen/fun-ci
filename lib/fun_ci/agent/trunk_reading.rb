# frozen_string_literal: true

require "time"
require_relative "../persistence/trunk_checks"
require_relative "../persistence/trunk_fetches"
require_relative "../trunk/shown"

module FunCi
  module Agent
    # How a run's commit stands against the project's trunk, as recorded:
    # its latest check, how old that is, and why the last fetch failed.
    class TrunkReading
      def initialize(db, project, clock)
        @checks = Persistence::TrunkChecks.new(db, project)
        @fetches = Persistence::TrunkFetches.new(db, project)
        @clock = clock
      end

      # A Trunk::Shown, or nil for a run that began no check.
      def for(run)
        check = @checks.latest(run[:commit_hash])
        return Trunk::Shown.of(check, now: @clock.now, fetch_error: @fetches.last&.error) if check

        started = run[:trunk_started_at]
        started && Trunk::Shown.unchecked(started: Time.parse(started), now: @clock.now)
      end
    end
  end
end
