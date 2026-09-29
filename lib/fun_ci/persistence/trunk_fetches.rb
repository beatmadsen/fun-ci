# frozen_string_literal: true

require "time"
require_relative "../trunk/fetch"
require_relative "../trunk/check"

module FunCi
  module Persistence
    # When fun-ci last fetched each project's trunk, and how that went
    # (architecture.md, Checking against the trunk). A fetch is claimed
    # in one statement, so of two processes claiming at once only one
    # fetches; after failures the interval doubles, up to an hour.
    class TrunkFetches
      LONGEST = 3600
      Last = Trunk::LastFetch

      def initialize(db, project)
        @db = db
        @project = project
      end

      # `now` when this process may fetch now, and the interval starts again; nil otherwise.
      def claim(now:, interval:)
        ensure_row
        @db.execute("UPDATE trunk_fetches SET claimed_at = ? WHERE project_path = ? AND (claimed_at IS NULL " \
                    "OR claimed_at + MIN(? * (1 << failures), ?) <= ?)",
                    [now.to_i, @project, interval, LONGEST, now.to_i])
        now if @db.changes == 1
      end

      def finished(fetched, at:)
        ensure_row
        return failed(fetched.error) if fetched.error

        @db.execute("UPDATE trunk_fetches SET fetched_at = ?, failures = 0, error = NULL WHERE project_path = ?",
                    [at.utc.iso8601, @project])
      end

      # The last fetch tried, or nil when there has been none.
      def last
        row = @db.execute("SELECT fetched_at, error FROM trunk_fetches WHERE project_path = ?", [@project]).first
        row && Last.new(fetched_at: row[0] && Time.parse(row[0]), error: row[1])
      end

      private

      def ensure_row
        @db.execute("INSERT OR IGNORE INTO trunk_fetches (project_path, failures) VALUES (?, 0)", [@project])
      end

      def failed(error)
        @db.execute("UPDATE trunk_fetches SET failures = failures + 1, error = ? WHERE project_path = ?",
                    [error, @project])
      end
    end
  end
end
