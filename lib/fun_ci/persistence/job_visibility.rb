# frozen_string_literal: true

require "time"

module FunCi
  module Persistence
    # Which daily and weekly jobs the console keeps out of view, and how
    # (design.md, The console): `ignored`, until it is shown again, or
    # `snoozed`, until the job runs again. It says nothing of whether a job
    # runs, and the agent commands don't read it.
    class JobVisibility
      # When a run began, if it did: not while it waits its turn, nor when
      # cancelled before it (design.md, Daily and weekly jobs), and once it
      # did, whatever became of it. fun-ci 2.4.0 and earlier kept no
      # `began_at`, so of their runs those that ran or are running began when they started.
      BEGAN = "COALESCE(run.began_at, CASE WHEN run.status IN ('running', 'completed', 'failed', 'timed_out') " \
              "THEN run.started_at END)"
      HIDDEN = <<~SQL.freeze
        SELECT job, kind FROM hidden_jobs AS hidden WHERE project_path = ? AND (kind = 'ignored' OR NOT EXISTS (
          SELECT 1 FROM job_runs AS run WHERE run.project_path = hidden.project_path AND run.job = hidden.job
            AND #{BEGAN} > hidden.hidden_at))
      SQL

      def initialize(db)
        @db = db
      end

      # Keeps the project's job `name` out of view from `at`, as `kind`:
      # `snoozed` or `ignored`. The latest of two decides.
      def hide(project, name, kind, at:)
        @db.execute("INSERT OR REPLACE INTO hidden_jobs (project_path, job, kind, hidden_at) VALUES (?, ?, ?, ?)",
                    [project, name, kind, at.utc.iso8601(3)])
      end

      def show(project, name)
        @db.execute("DELETE FROM hidden_jobs WHERE project_path = ? AND job = ?", [project, name])
      end

      # { name => kind } of the project's jobs out of view now.
      def hidden(project) = @db.execute(HIDDEN, [project]).to_h
    end
  end
end
