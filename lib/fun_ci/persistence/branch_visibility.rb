# frozen_string_literal: true

require "time"

module FunCi
  module Persistence
    # Which branches the console keeps out of view, and how (design.md, The
    # console): `ignored`, until it is shown again, or `snoozed`, until a run
    # of the branch starts after the snooze. Like JobVisibility, it says
    # nothing of whether a branch runs, and the agent commands don't read it.
    class BranchVisibility
      # A run is kept to the second and a snooze to the millisecond, so they
      # are compared as times; a run in the second of the snooze doesn't end it.
      HIDDEN = <<~SQL
        SELECT project_path, branch, kind FROM hidden_branches AS hidden WHERE kind = 'ignored' OR NOT EXISTS (
          SELECT 1 FROM pipeline_runs AS run WHERE run.project_path = hidden.project_path
            AND run.branch = hidden.branch
            AND julianday(run.created_at) > julianday(hidden.hidden_at))
      SQL

      def initialize(db)
        @db = db
      end

      # Keeps the project's `branch` out of view from `at`, as `kind`:
      # `snoozed` or `ignored`. The latest of two decides.
      def hide(project, branch, kind, at:)
        @db.execute("INSERT OR REPLACE INTO hidden_branches (project_path, branch, kind, hidden_at) " \
                    "VALUES (?, ?, ?, ?)", [project, branch, kind, at.utc.iso8601(3)])
      end

      def show(project, branch)
        @db.execute("DELETE FROM hidden_branches WHERE project_path = ? AND branch = ?", [project, branch])
      end

      # { [project, branch] => kind } of the branches out of view now.
      def hidden = @db.execute(HIDDEN).to_h { |project, branch, kind| [[project, branch], kind] }
    end
  end
end
