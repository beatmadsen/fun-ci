# frozen_string_literal: true

require "json"
require "time"
require_relative "../trunk/check"

module FunCi
  module Persistence
    # A project's checks against its trunk. A check is a fact about a commit
    # and a trunk SHA, so each pair is written once and never changed.
    class TrunkChecks
      TIP = %i[trunk_remote trunk_branch trunk_sha trunk_seen_at].freeze
      MERGE = %i[outcome ahead behind files reason].freeze
      COLUMNS = [:commit_hash, *TIP, *MERGE].freeze
      SELECT = "SELECT #{COLUMNS.join(", ")} FROM trunk_checks".freeze

      def initialize(db, project)
        @db = db
        @project = project
      end

      def record(check, checked_at:)
        @db.execute("INSERT OR IGNORE INTO trunk_checks (project_path, checked_at, #{COLUMNS.join(", ")}) " \
                    "VALUES (?, ?, #{(["?"] * COLUMNS.size).join(", ")})",
                    [@project, checked_at.utc.iso8601, check.commit, *tip_row(check.tip), *merge_row(check.merge)])
      end

      # A fetch found the trunk still at `sha`: the checks against it are as fresh as that fetch.
      def seen(sha, at:)
        @db.execute("UPDATE trunk_checks SET trunk_seen_at = ? WHERE project_path = ? AND trunk_sha = ?",
                    [at.utc.iso8601, @project, sha])
      end

      # The commit's check against the trunk SHA fun-ci saw last, or nil.
      def latest(sha)
        found = @db.execute("#{SELECT} WHERE project_path = ? AND commit_hash = ? " \
                            "ORDER BY COALESCE(trunk_seen_at, checked_at) DESC, id DESC LIMIT 1", [@project, sha]).first
        found && Trunk::Check.new(commit: found.first, tip: tip(found[1, TIP.size]),
                                  merge: merge(found.last(MERGE.size)))
      end

      # { commit => trunk SHA } for each branch's newest run, other than `except`,
      # whose commit has been checked against a trunk tip.
      def branch_heads(except:)
        heads = @db.execute("SELECT commit_hash FROM pipeline_runs WHERE id IN (SELECT MAX(id) FROM pipeline_runs " \
                            "WHERE project_path = ? GROUP BY branch) AND commit_hash != ?", [@project, except]).flatten
        heads.to_h { |sha| [sha, latest(sha)&.tip&.sha] }.compact
      end

      private

      def tip_row(tip) = tip ? [tip.remote, tip.branch, tip.sha, tip.seen_at.utc.iso8601] : [nil] * TIP.size
      def merge_row(merge) = [merge.outcome, merge.ahead, merge.behind, JSON.generate(merge.files), merge.reason]

      def tip(values)
        remote, branch, sha, seen_at = values
        return nil unless sha

        Trunk::Tip.new(remote: remote, branch: branch, sha: sha, seen_at: Time.parse(seen_at))
      end

      def merge(values)
        outcome, ahead, behind, files, reason = values
        Trunk::Merge.new(outcome: outcome, ahead: ahead, behind: behind, files: JSON.parse(files), reason: reason)
      end
    end
  end
end
