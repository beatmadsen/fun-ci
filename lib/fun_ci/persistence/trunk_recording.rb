# frozen_string_literal: true

require_relative "pipeline_run"
require_relative "trunk_checks"
require_relative "trunk_fetches"

module FunCi
  module Persistence
    # What a run records about the trunk (docs/trunk-conflicts.md), under the
    # run's project. Expects @db and @pipeline_run_id, and #tolerating.
    module TrunkRecording
      # A fetch that never happens, for a run whose project can't be read.
      class NoFetches
        def claim(now:, **) = now
        def last = nil
      end

      def trunk_fetches = tolerating { TrunkFetches.new(@db, project) } || NoFetches.new

      # The fetch's process group, which cancelling the run kills.
      def trunk_fetch_process(pgid)
        tolerating { @db.execute("UPDATE pipeline_runs SET fetch_pgid = ? WHERE id = ?", [pgid, @pipeline_run_id]) }
      end

      # How the fetch went; a tip it fetched counts as seen now in every check against it.
      def trunk_fetched(fetched, tip)
        tolerating do
          TrunkFetches.new(@db, project).finished(fetched, at: Time.now)
          TrunkChecks.new(@db, project).seen(tip.sha, at: Time.now) if tip && !fetched.error
        end
      end

      def trunk_checked(check)
        tolerating { TrunkChecks.new(@db, project).record(check, checked_at: Time.now) }
      end

      private

      def project = PipelineRun.find(@db, @pipeline_run_id)[:project_path]
    end
  end
end
