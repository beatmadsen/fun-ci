# frozen_string_literal: true

require_relative "../persistence/stage_job"
require_relative "../persistence/raw_outputs"
require_relative "../persistence/trunk_checks"
require "time"
require_relative "../trunk/shown"

module FunCi
  module Agent
    # What is recorded about one of a project's runs beyond its row: its
    # stages, the raw output they kept, and its commit's check against the trunk.
    class RunDetails
      def initialize(db, project, clock)
        @db = db
        @raw = Persistence::RawOutputs.beside(db.filename("main"))
        @trunk_checks = Persistence::TrunkChecks.new(db, project)
        @clock = clock
      end

      def jobs(run)
        Persistence::StageJob.for_run(@db, run[:id]).map { |job| job.merge(raw_bytes: @raw.bytes(job[:id])) }
      end

      # What the stage kept of its raw output, or nil.
      def raw_output(stage) = stage.id && @raw.read(stage.id)

      # How the run's commit stands against the trunk, or nil for a run that began no check.
      def trunk(run)
        check = @trunk_checks.latest(run[:commit_hash])
        return Trunk::Shown.of(check, now: @clock.now) if check

        started = run[:trunk_started_at]
        started && Trunk::Shown.unchecked(started: Time.parse(started), now: @clock.now)
      end
    end
  end
end
