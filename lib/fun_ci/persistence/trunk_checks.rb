# frozen_string_literal: true

require "json"
require "time"
require_relative "../trunk/check"

module FunCi
  module Persistence
    # A project's checks against its trunk. A check is a fact about a commit
    # and a trunk SHA, so each pair is written once and never changed.
    class TrunkChecks
      COLUMNS = %i[commit_hash trunk_ref trunk_sha trunk_seen_at outcome ahead behind files reason].freeze

      def initialize(db, project)
        @db = db
        @project = project
      end

      def record(check, checked_at:)
        @db.execute("INSERT OR IGNORE INTO trunk_checks (project_path, checked_at, #{COLUMNS.join(", ")}) " \
                    "VALUES (?, ?, #{(["?"] * COLUMNS.size).join(", ")})",
                    [@project, checked_at.utc.iso8601, *row(check)])
      end

      # The commit's check against the trunk SHA fun-ci saw last, or nil.
      def latest(sha)
        found = @db.execute("SELECT #{COLUMNS.join(", ")} FROM trunk_checks WHERE project_path = ? " \
                            "AND commit_hash = ? ORDER BY trunk_seen_at DESC, id DESC LIMIT 1", [@project, sha]).first
        found && check(found)
      end

      private

      def row(check)
        tip = check.tip
        merge = check.merge
        [check.commit, tip.ref, tip.sha, tip.seen_at.utc.iso8601, merge.outcome, merge.ahead, merge.behind,
         JSON.generate(merge.files), merge.reason]
      end

      def check(found)
        commit, ref, sha, seen_at, outcome, ahead, behind, files, reason = found
        Trunk::Check.new(commit: commit, tip: Trunk::Tip.new(ref: ref, sha: sha, seen_at: Time.parse(seen_at)),
                         merge: Trunk::Merge.new(outcome: outcome, ahead: ahead, behind: behind,
                                                 files: JSON.parse(files), reason: reason))
      end
    end
  end
end
