# frozen_string_literal: true

require_relative "../persistence/trunk_checks"
require_relative "../persistence/trunk_fetches"
require_relative "../trunk/shown"

module FunCi
  module Console
    # What the console shows of the trunk (design.md, The
    # trunk). The standing belongs to a branch, not a run: it is shown on
    # the branch's newest run and is the branch's latest settled check, so a
    # new run still checking, or whose check couldn't be made, keeps it.
    class TrunkMarks
      def initialize(db)
        @db = db
      end

      # runs: newest first. Each gains :trunk, { branch_state:, trunk: } on a
      # branch's newest run with a settled check, nil otherwise.
      def mark(runs)
        branches = runs.group_by { |run| run.values_at(:project_path, :branch) }.values
        standing = branches.to_h { |branch_runs| [branch_runs.first[:id], standing(branch_runs)] }
        runs.map { |run| run.merge(trunk: standing[run[:id]]) }
      end

      # [{ project:, since: }] for each project on the page whose trunk is
      # stale: its last fetch failed, or its last good one (since, epoch
      # seconds, nil for none) is over an hour old.
      def stale(runs, now:)
        runs.filter_map { |run| run[:project_path] }.uniq.filter_map { |project| stale_since(project, now) }
      end

      private

      def standing(branch_runs)
        check = branch_runs.lazy.filter_map { |run| settled(run) }.first
        check && { branch_state: Trunk::Shown.of(check, now: Time.now).state, trunk: check.tip.branch }
      end

      def settled(run)
        check = Persistence::TrunkChecks.new(@db, run[:project_path]).latest(run[:commit_hash])
        check if check && check.merge.outcome != "unknown"
      end

      def stale_since(project, now)
        last = Persistence::TrunkFetches.new(@db, project).last
        return nil unless last && (last.error || now - last.fetched_at > Trunk::Shown::FRESH_FOR)

        { project: project, since: last.fetched_at&.to_i }
      end
    end
  end
end
