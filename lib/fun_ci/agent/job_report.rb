# frozen_string_literal: true

require "time"
require_relative "report_stage"
require_relative "verdict"
require_relative "../jobs/folders"
require_relative "../jobs/due"
require_relative "../persistence/job_runs"
require_relative "../persistence/raw_outputs"

module FunCi
  module Agent
    # A daily or weekly job as an agent is told it: the job, the commit and
    # branch its latest run tested, that run as a RunReport::Stage named after
    # the job (nil while it never ran), when that run started, and when the
    # job is due again.
    JobReport = Data.define(:job, :sha, :branch, :stage, :started_at, :due_at)

    class JobReport
      VERDICTS = { "passed" => :passed, "failed" => :failed, "over_budget" => :over_budget,
                   "running" => :undecided }.freeze

      def name = job.name
      def cadence = job.cadence

      # Its latest run's state, or `due` when it never ran.
      def state = stage ? stage.state : "due"

      # As `status` would exit for a stage in this state; a job that never ran, or was cancelled, has none.
      def verdict = VERDICTS.fetch(state, :unknown)

      # Whether the next commit starts it.
      def due? = state != "running" && due_at.nil?
    end

    # The daily and weekly jobs of a project, as JobReports.
    class JobReports
      def initialize(db, project, clock)
        @db = db
        @project = project
        @clock = clock
      end

      # By name.
      def all = Jobs::Folders.new(@project).jobs.map { |job| report(job) }

      # The job named, or nil when the project has no such job.
      def named(name) = all.find { |report| report.name == name }

      # The jobs whose latest run tested `sha`.
      def on_commit(sha) = all.select { |report| report.sha == sha }

      # What the job's latest run kept of its raw output, or nil.
      def raw_output(report) = report.stage && raw.read(report.stage.id)

      private

      def raw = Persistence::RawOutputs.for_jobs(@db.filename("main"))

      def report(job)
        row = Persistence::JobRuns.new(@db, @project).latest(job.name)
        JobReport.new(job: job, sha: row&.dig(:commit_hash), branch: row&.dig(:branch), stage: row && stage(job, row),
                      started_at: row && Time.parse(row[:started_at]),
                      due_at: Jobs::Due.new(row, job.period, now: @clock.now).at)
      end

      def stage(job, row)
        RunReport::Stage.from_row(job.name, row.merge(budget: Jobs::Job::BUDGET, raw_bytes: raw.bytes(row[:id])))
      end
    end
  end
end
