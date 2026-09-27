# frozen_string_literal: true

require_relative "pipeline_run"

module FunCi
  module Persistence
    # The runs of one project. Every project records its runs in the same
    # database, so each query is scoped to the project's path.
    class ProjectRuns
      def initialize(db, project)
        @db = db
        @project = project
      end

      def latest_of_commit(sha) = query("AND commit_hash = ? ORDER BY id DESC LIMIT 1", sha).first

      # The commit of the first run on the same branch after this one, if any.
      def superseded_by(run)
        query("AND branch = ? AND id > ? ORDER BY id LIMIT 1", run[:branch], run[:id]).first&.fetch(:commit_hash)
      end

      # The newest runs first, on one branch when one is named.
      def recent(limit:, branch: nil)
        return query("ORDER BY id DESC LIMIT ?", limit) unless branch

        query("AND branch = ? ORDER BY id DESC LIMIT ?", branch, limit)
      end

      # Drops the kept output and reported failures of every run but the
      # project's newest `keep`, and marks their stages pruned.
      def forget_output(keep:)
        @db.execute("UPDATE stage_jobs SET output_tail = NULL, failures = NULL, pruned = 1 WHERE pipeline_run_id IN " \
                    "(SELECT id FROM pipeline_runs WHERE project_path = ? ORDER BY id DESC LIMIT -1 OFFSET ?)",
                    [@project, keep])
      end

      private

      def query(clause, *params)
        @db.execute("#{PipelineRun::SELECT} WHERE project_path = ? #{clause}", [@project, *params])
           .map { |row| PipelineRun::COLUMNS.zip(row).to_h }
      end
    end
  end
end
