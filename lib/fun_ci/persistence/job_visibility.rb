# frozen_string_literal: true

require "time"

module FunCi
  module Persistence
    # Which daily and weekly jobs the console keeps out of view, and how
    # (design.md, The console): `ignored`, until it is shown again, or
    # `snoozed`, until the job runs again. It says nothing of whether a job
    # runs, and the agent commands don't read it.
    class JobVisibility
      # A run that counts as the job running again: one that began, and was
      # not cancelled (design.md, Daily and weekly jobs).
      RAN = "status IN ('running', 'completed', 'failed', 'timed_out')"
      HIDDEN = <<~SQL.freeze
        SELECT job, kind FROM hidden_jobs AS hidden WHERE project_path = ? AND (kind = 'ignored' OR NOT EXISTS (
          SELECT 1 FROM job_runs AS run WHERE run.project_path = hidden.project_path AND run.job = hidden.job
            AND run.started_at > hidden.hidden_at AND run.#{RAN}))
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
