# frozen_string_literal: true

require "time"
require_relative "../jobs/due"
require_relative "raw_outputs"
require_relative "active_jobs"

module FunCi
  module Persistence
    # The runs of one project's daily and weekly jobs (architecture.md, Daily
    # and weekly jobs), apart from its pipeline runs.
    class JobRuns
      COLUMNS = %i[id project_path job cadence commit_hash branch status started_at completed_at lock_file pid
                   group_pid exit_status signal output_tail evidence].freeze
      SELECT = "SELECT #{COLUMNS.join(", ")} FROM job_runs".freeze
      KEPT = 10

      def initialize(db, project)
        @db = db
        @project = project
      end

      # Records a run of `job` running, testing `commit` ({ sha:, branch: }),
      # and answers its id, when the job is due at `now`; nil otherwise. The
      # job's latest run is read and the new one written in one transaction,
      # so of two claims at once only one starts it. A claim forgets the
      # job's runs beyond its newest 10.
      def claim(job, commit:, lock_file:, now:)
        @db.transaction(:immediate) do
          next nil unless Jobs::Due.new(latest(job.name), job.period, now: now).now?

          insert(job, commit, lock_file, now).tap { forget_beyond(job.name) }
        end
      end

      # The job's newest run, or nil when it never ran.
      def latest(name) = query("WHERE project_path = ? AND job = ? ORDER BY id DESC LIMIT 1", @project, name).first

      def cancelled(id) = ActiveJobs.cancelled(@db, id)

      # Records failed the job's runs still running, whose process is known to be gone.
      def died(name)
        @db.execute("UPDATE job_runs SET status = 'failed', completed_at = ? " \
                    "WHERE project_path = ? AND job = ? AND status = 'running'", [stamp(Time.now), @project, name])
      end

      private

      def insert(job, commit, lock_file, now)
        @db.execute("INSERT INTO job_runs (project_path, job, cadence, commit_hash, branch, status, started_at, " \
                    "lock_file) VALUES (?, ?, ?, ?, ?, 'running', ?, ?)",
                    [@project, job.name, job.cadence, commit[:sha], commit[:branch], stamp(now), lock_file])
        @db.last_insert_row_id
      end

      def forget_beyond(name)
        ids = @db.execute("SELECT id FROM job_runs WHERE project_path = ? AND job = ? ORDER BY id DESC " \
                          "LIMIT -1 OFFSET ?", [@project, name, KEPT]).flatten
        @db.execute("DELETE FROM job_runs WHERE id IN (#{ids.map { "?" }.join(", ")})", ids) if ids.any?
        RawOutputs.for_jobs(@db.filename("main")).delete(ids)
      end

      def stamp(time) = time.utc.iso8601(3)

      def query(clause, *params)
        @db.execute("#{SELECT} #{clause}", params).map { |row| COLUMNS.zip(row).to_h }
      end
    end
  end
end
