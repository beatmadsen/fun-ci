# frozen_string_literal: true

require_relative "../persistence/project_runs"
require_relative "run_details"
require_relative "run_report"

module FunCi
  module Agent
    # The runs of the project git names, as an agent is told them.
    class Reports
      def initialize(db, git, clock)
        @db = db
        @git = git
        project = git.toplevel
        @runs = Persistence::ProjectRuns.new(db, project)
        @details = RunDetails.new(db, project, clock)
      end

      # What the stage kept of its raw output, or nil.
      def raw_output(stage) = @details.raw_output(stage)

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
        RunReport.build(run: run, jobs: @details.jobs(run), need: need,
                        commit: { subject: @git.subject(run[:commit_hash]), superseded_by: superseded_by,
                                  trunk: @details.trunk(run) })
      end
    end
  end
end
