# frozen_string_literal: true

require_relative "../persistence/project_runs"
require_relative "../persistence/stage_job"
require_relative "run_report"

module FunCi
  module Agent
    # A commit's newest run in the project git names, as an agent is told it.
    class Reports
      def initialize(db, git)
        @db = db
        @git = git
        @runs = Persistence::ProjectRuns.new(db, git.toplevel)
      end

      def for(sha, need)
        run = @runs.latest_of_commit(sha)
        run && report(run, need)
      end

      private

      def report(run, need)
        superseded_by = run[:status] == "cancelled" ? @runs.superseded_by(run) : nil
        RunReport.build(run: run, jobs: Persistence::StageJob.for_run(@db, run[:id]), need: need,
                        commit: { subject: @git.subject(run[:commit_hash]), superseded_by: superseded_by })
      end
    end
  end
end
