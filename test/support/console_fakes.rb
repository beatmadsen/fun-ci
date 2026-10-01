# frozen_string_literal: true

require "json"

# Stand-ins for ConsoleSession's collaborators: a BoardData that serves
# fixed runs and job rows and counts cancels, pages loaded and checks for
# dead slow suites and jobs, and a renderer port that keeps each message as the JSON the
# renderer would read.
module ConsoleFakes
  class BoardData
    attr_reader :cancelled, :loads, :dead_checks
    attr_accessor :runs, :stale, :job_rows

    def initialize(runs)
      @runs = runs
      @cancelled = []
      @loads = 0
      @dead_checks = []
    end

    def streak = 3
    def load_more = @loads += 1
    def resize(_page_size) = nil
    def more? = false
    def record_dead_slow_suites = @dead_checks << :slow_suites
    def record_dead_jobs = @dead_checks << :jobs
    def cancel_run(id) = @cancelled << id
    def cancel_job(id) = @cancelled << "job #{id}"
    def jobs(_runs) = job_rows || []
    def stale_trunks(_runs, now:) = now && (stale || [])
  end

  class Port
    attr_reader :sent

    def initialize
      @sent = []
    end

    def write(message) = @sent << JSON.parse(JSON.generate(message))
  end

  class Log
    attr_reader :lines

    def initialize
      @lines = []
    end

    def write(text) = @lines << text
  end

  def self.run_row(id, status: "completed")
    { id: id, commit_hash: "a" * 40, branch: "main", status: status, project_path: nil,
      created_at: "2026-09-25T10:00:00Z", updated_at: "2026-09-25T10:01:00Z", stages: [] }
  end

  # A job row as BoardData answers it, its latest run's id `id` (nil: it never ran).
  def self.job_row(name, status: "completed", id: 1)
    { project: "/p", name: name, cadence: "daily", status: status, due_at: nil,
      run: id && { id: id, commit_hash: "b" * 40, branch: "main", status: status,
                   started_at: "2026-09-25T09:00:00.000Z", completed_at: ended(status) } }
  end

  # When a fake job run ended: never while it runs.
  def self.ended(status) = status == "running" ? nil : "2026-09-25T09:30:00.000Z"

  # A run whose `fast` stage has `status`.
  def self.fast_stage(id, status)
    run_row(id, status: "running").merge(stages: [{ stage: "fast", status: status, duration: nil,
                                                    started_at: "2026-09-25T10:00:00Z" }])
  end
end
