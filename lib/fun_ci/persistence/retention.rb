# frozen_string_literal: true

require_relative "project_runs"
require_relative "raw_outputs"
require_relative "stage_job"

module FunCi
  module Persistence
    # How long fun-ci keeps what failed stages left, applied when a run
    # starts: the evidence for a project's 50 newest runs, the raw output for
    # its 10 newest, and no raw output whose stage row is gone.
    module Retention
      KEPT_RUNS = 50
      KEPT_RAW = 10

      def self.apply(db, project)
        runs = ProjectRuns.new(db, project)
        runs.forget_output(keep: KEPT_RUNS)
        raw = RawOutputs.beside(db.filename("main"))
        raw.delete(runs.stage_ids_beyond(keep: KEPT_RAW))
        raw.keep_only(StageJob.ids(db))
      end
    end
  end
end
