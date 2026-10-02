# frozen_string_literal: true

require "time"
require_relative "report_stage"
require_relative "verdict"
require_relative "../jobs/standings"
require_relative "../persistence/raw_outputs"

module FunCi
  module Agent
    # A daily or weekly job as an agent is told it: where it stands
    # (Jobs::Standing), and its latest run as a RunReport::Stage named after
    # the job, nil while it never ran, and the seconds until a run waiting its
    # turn starts (Jobs::Schedule), nil for any other.
    JobReport = Data.define(:standing, :stage, :starts_in)

    # The jobs `status` names for a commit: those whose latest run tested it,
    # and those failing on another commit, which an agent would not hear of otherwise.
    CommitJobs = Data.define(:on_commit, :failing)

    class CommitJobs
      NONE = new(on_commit: [], failing: [])
    end

    class JobReport
      VERDICTS = { "passed" => :passed, "failed" => :failed, "lost" => :failed, "over_budget" => :over_budget,
                   "running" => :undecided, "scheduled" => :undecided }.freeze

      def name = standing.name
      def cadence = standing.cadence
      def state = standing.state
      def needs_you? = standing.needs_you?
      def due_at = standing.due_at

      # Whether the next commit starts it.
      def due? = standing.due_now?

      # The commit and branch its latest run tested, and when that started,
      # or, while it waits its turn, when it is to.
      def sha = standing.run&.dig(:commit_hash)
      def branch = standing.run&.dig(:branch)
      def started_at = standing.run && !starts_at ? Time.parse(standing.run[:started_at]) : nil
      def starts_at = standing.starts_at

      # As `status` would exit for a stage in this state; a job that never ran, or was cancelled, has none.
      def verdict = VERDICTS.fetch(state, :unknown)
    end

    # The daily and weekly jobs of a project, as JobReports.
    class JobReports
      def initialize(db, project, clock)
        @db = db
        @project = project
        @clock = clock
      end

      # By name.
      def all = Jobs::Standings.new(@db, @project, now: @clock.now).all.map { |standing| report(standing) }

      # The job named, or nil when the project has no such job.
      def named(name) = all.find { |report| report.name == name }

      # The jobs whose latest run tested `sha`, and those failing on another commit.
      def of_commit(sha)
        reports = all
        CommitJobs.new(on_commit: reports.select { |report| report.sha == sha },
                       failing: reports.select { |report| report.needs_you? && report.sha != sha })
      end

      # What the job's latest run kept of its raw output, or nil.
      def raw_output(report) = report.stage && raw.read(report.stage.id)

      private

      def raw = Persistence::RawOutputs.for_jobs(@db.filename("main"))

      def report(standing)
        run = standing.run
        JobReport.new(standing: standing, stage: run && stage(standing.name, run),
                      starts_in: standing.starts_at && (standing.starts_at - @clock.now))
      end

      def stage(name, run)
        RunReport::Stage.from_row(name,
                                  run.merge(budget: run[:budget] || Jobs::Job::BUDGET, raw_bytes: raw.bytes(run[:id])))
      end
    end
  end
end
