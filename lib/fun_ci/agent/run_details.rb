# frozen_string_literal: true

require_relative "../persistence/stage_job"
require_relative "../persistence/raw_outputs"
require_relative "trunk_reading"

module FunCi
  module Agent
    # What is recorded about one of a project's runs beyond its row: its
    # stages, the raw output they kept, and its commit's check against the trunk.
    class RunDetails
      # trunk: reads the run's trunk (a TrunkReading).
      def initialize(db, trunk)
        @db = db
        @raw = Persistence::RawOutputs.beside(db.filename("main"))
        @trunk = trunk
      end

      def jobs(run)
        Persistence::StageJob.for_run(@db, run[:id]).map { |job| job.merge(raw_bytes: @raw.bytes(job[:id])) }
      end

      # What the stage kept of its raw output, or nil.
      def raw_output(stage) = stage.id && @raw.read(stage.id)

      # How the run's commit stands against the trunk, or nil for a run that began no check.
      def trunk(run) = @trunk.for(run)
      def recheck_trunk(sha) = @trunk.recheck(sha)
    end
  end
end
