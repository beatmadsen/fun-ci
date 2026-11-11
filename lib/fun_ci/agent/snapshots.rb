# frozen_string_literal: true

require_relative "../persistence/project_runs"
require_relative "../persistence/stage_job"
require_relative "run_report"
require_relative "events"
require_relative "trunk_reading"
require_relative "trunk_json"
require_relative "job_events"
require_relative "../jobs/state"
require_relative "../persistence/job_runs"

module FunCi
  module Agent
    # Looks at the newest runs of the project git names, as `events` compares
    # them: { run id => Events::RunState }; and at its newest daily and weekly
    # job runs: { job run id => JobEvents::JobState }.
    class Snapshots
      def initialize(db, git, clock)
        project = git.toplevel
        @db = db
        @runs = Persistence::ProjectRuns.new(db, project)
        @job_runs = Persistence::JobRuns.new(db, project)
        @trunk = TrunkReading.new(db, project, clock, TrunkReading::UNREAD)
      end

      def take(limit:)
        @runs.recent(limit: limit, branch: nil).to_h { |run| [run[:id], state_of(run)] }
      end

      def jobs(limit:)
        @job_runs.recent(limit: limit).to_h { |run| [run[:id], job_state(run)] }
      end

      private

      def job_state(run)
        JobEvents::JobState.new(id: run[:id], job: run[:job], cadence: run[:cadence], sha: run[:commit_hash],
                                branch: run[:branch], state: Jobs::State.of(run),
                                seconds: Persistence::StageJob.elapsed_duration(run)&.round(1),
                                starts_at: starts_at(run), times: job_times(run))
      end

      def job_times(run)
        JobEvents::JobTimes.new(claimed: stamp(run[:claimed_at]), started: stamp(run[:started_at]),
                                ended: stamp(run[:completed_at]))
      end

      # When a run waiting its turn starts, as an ISO time; nil for any other.
      def starts_at(run) = run[:status] == "scheduled" ? Time.parse(run[:started_at]).utc.iso8601 : nil

      def state_of(run)
        superseded_by = run[:status] == "cancelled" ? @runs.superseded_by(run) : nil
        shown = recorded_check(run)
        Events::RunState.new(id: run[:id], sha: run[:commit_hash], branch: run[:branch], status: run[:status],
                             finished: finished(run), superseded_by: superseded_by,
                             trunk: shown && TrunkJson.document(shown), times: times(run, shown))
      end

      # The latest check recorded, as shown; nil for a check still going, which has none yet.
      def recorded_check(run)
        shown = @trunk.for(run)
        shown&.check ? shown : nil
      end

      def times(run, shown)
        checked = shown&.check&.checked_at
        Events::RunTimes.new(started: stamp(run[:created_at]), changed: stamp(run[:updated_at]),
                             checked: checked&.utc&.iso8601)
      end

      # A time the database kept, as events say it: ISO 8601, UTC, to the second.
      def stamp(kept) = kept && Time.parse(kept).utc.iso8601

      def finished(run)
        jobs = Persistence::StageJob.for_run(@db, run[:id]).select { |job| job[:finished_order] }
        stages = RunReport.stages(jobs).to_h { |stage| [stage.name, stage] }
        jobs.sort_by { |job| job[:finished_order] }.map { |job| facts(stages.fetch(job[:stage]), job) }
      end

      def facts(stage, job)
        { stage: stage.name, state: stage.state, seconds: stage.seconds, at: stamp(job[:completed_at]) }
      end
    end
  end
end
