# frozen_string_literal: true

require "time"

module FunCi
  module Persistence
    # A run's status, worked out from its stages alone (acceptance-tests.md,
    # AT-7.1): failed once any stage failed or timed out, completed once all
    # four passed, and unchanged until then. One statement reads the stage rows
    # and writes the run, so the foreground pipeline and the forked slow suite
    # can't overwrite each other's verdict; failed, completed and cancelled
    # runs are never touched again.
    module RunStatus
      OF_RUN = "pipeline_runs.id = stage_jobs.pipeline_run_id"
      DERIVED = <<~SQL.freeze
        CASE
          WHEN EXISTS (SELECT 1 FROM stage_jobs WHERE #{OF_RUN} AND status IN ('failed', 'timed_out')) THEN 'failed'
          WHEN (SELECT COUNT(DISTINCT stage) FROM stage_jobs WHERE #{OF_RUN} AND status = 'completed'
                AND stage IN ('lint', 'build', 'fast', 'slow')) = 4 THEN 'completed'
          ELSE status
        END
      SQL
      SETTLE = "UPDATE pipeline_runs SET status = #{DERIVED}, updated_at = ? " \
               "WHERE id = ? AND status IN ('scheduled', 'running') AND status != #{DERIVED}".freeze

      def self.settle(db, id)
        db.execute(SETTLE, [Time.now.utc.iso8601, id])
      end
    end
  end
end
