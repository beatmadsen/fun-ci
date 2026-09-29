# frozen_string_literal: true

require_relative "../persistence/project_runs"
require_relative "../persistence/stage_job"
require_relative "run_report"
require_relative "events"
require_relative "trunk_reading"
require_relative "trunk_json"

module FunCi
  module Agent
    # Looks at the newest runs of the project git names, as `events` compares
    # them: { run id => Events::RunState }.
    class Snapshots
      def initialize(db, git, clock)
        project = git.toplevel
        @db = db
        @runs = Persistence::ProjectRuns.new(db, project)
        @trunk = TrunkReading.new(db, project, clock, TrunkReading::UNREAD)
      end

      def take(limit:)
        @runs.recent(limit: limit, branch: nil).to_h { |run| [run[:id], state_of(run)] }
      end

      private

      def state_of(run)
        superseded_by = run[:status] == "cancelled" ? @runs.superseded_by(run) : nil
        Events::RunState.new(id: run[:id], sha: run[:commit_hash], branch: run[:branch], status: run[:status],
                             finished: finished(run), superseded_by: superseded_by, trunk: trunk(run))
      end

      # The latest check recorded; a check still going has none yet.
      def trunk(run)
        shown = @trunk.for(run)
        shown&.check ? TrunkJson.document(shown) : nil
      end

      def finished(run)
        jobs = Persistence::StageJob.for_run(@db, run[:id]).select { |job| job[:finished_order] }
        stages = RunReport.stages(jobs).to_h { |stage| [stage.name, stage] }
        jobs.sort_by { |job| job[:finished_order] }.map { |job| facts(stages.fetch(job[:stage])) }
      end

      def facts(stage) = { stage: stage.name, state: stage.state, seconds: stage.seconds }
    end
  end
end
