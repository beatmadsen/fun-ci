# frozen_string_literal: true

require_relative "../persistence/project_runs"
require_relative "../persistence/stage_job"
require_relative "run_report"

module FunCi
  module Agent
    # The runs of the project git names, as an agent is told them.
    class Reports
      def initialize(db, git)
        @db = db
        @git = git
        @runs = Persistence::ProjectRuns.new(db, git.toplevel)
      end

      # The commit's newest run, or nil.
      def for(sha, need)
        run = @runs.latest_of_commit(sha)
        run && of(run, need)
      end

      # Notes that an agent is waiting on the commit's newest run, as of `at`.
      def mark_waited(sha, at)
        run = @runs.latest_of_commit(sha)
        Persistence::PipelineRun.mark_waited(@db, run[:id], at.utc.iso8601) if run
      end

      # [[run, its report for the whole pipeline], ...], newest first.
      def recent(limit:, branch:)
        @runs.recent(limit: limit, branch: branch).map { |run| [run, of(run, "all")] }
      end

      def of(run, need)
        superseded_by = run[:status] == "cancelled" ? @runs.superseded_by(run) : nil
        RunReport.build(run: run, jobs: Persistence::StageJob.for_run(@db, run[:id]), need: need,
                        commit: { subject: @git.subject(run[:commit_hash]), superseded_by: superseded_by })
      end
    end
  end
end
