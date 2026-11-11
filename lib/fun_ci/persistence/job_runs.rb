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
                   group_pid exit_status signal output_tail evidence budget claimed_at].freeze
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
      # job's runs beyond its newest 10. A block is given the id inside that
      # transaction, so what it records of the run (that it waits its turn)
      # is there the moment anyone else can read the run.
      def claim(job, commit:, lock_file:, now:, &then_record)
        @db.transaction(:immediate) do
          next nil unless Jobs::Due.new(latest(job.name), job.period, now: now).now?

          insert(job, commit, lock_file, now).tap { |id| claimed(job.name, id, then_record) }
        end
      end

      # Records the claimed run `id` waiting its turn to start at `at` (Jobs::Schedule).
      def wait_until(id, at) = update(id, "scheduled", at, "status = 'running'")

      # Records the run `id` running from `now`, its turn come, and answers how
      # many runs that was: none when it was cancelled while it waited.
      def start_turn(id, now) = update(id, "running", now, "status = 'scheduled'")

      # The project's newest job runs, newest first.
      def recent(limit:) = query("WHERE project_path = ? ORDER BY id DESC LIMIT ?", @project, limit)

      # The job's newest run, or nil when it never ran.
      def latest(name) = query("WHERE project_path = ? AND job = ? ORDER BY id DESC LIMIT 1", @project, name).first

      # Records failed the job's runs still running, whose process is known to be gone.
      def died(name) = ActiveJobs.running_of(@db, @project, name).each { |id| ActiveJobs.died(@db, id) }

      private

      def insert(job, commit, lock_file, now)
        @db.execute("INSERT INTO job_runs (project_path, job, cadence, commit_hash, branch, status, started_at, " \
                    "claimed_at, began_at, lock_file) VALUES (?, ?, ?, ?, ?, 'running', ?, ?, ?, ?)",
                    [@project, job.name, job.cadence, commit[:sha], commit[:branch], *[stamp(now)] * 3, lock_file])
        @db.last_insert_row_id
      end

      def claimed(name, id, then_record)
        forget_beyond(name)
        then_record&.call(id)
      end

      # A run began once it runs: began_at says when, and is none while it waits its turn.
      def update(id, status, at, was)
        began = stamp(at) if status == "running"
        @db.execute("UPDATE job_runs SET status = ?, started_at = ?, began_at = ? WHERE id = ? AND #{was}",
                    [status, stamp(at), began, id])
        @db.changes
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
