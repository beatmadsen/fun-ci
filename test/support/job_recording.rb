# frozen_string_literal: true

require "json"
require "fileutils"
require "fun_ci/persistence/raw_outputs"
require "fun_ci/evidence/document"

# Daily and weekly jobs for the agent commands' tests: a job's script in the
# project, and its runs as JobRun records them, at times the test chooses.
# Expects #db, #clock and a project directory from #job_project.
module JobRecording
  # A run's facts: status as job_runs keeps it, when it started (seconds before
  # the clock's now), how long it ran, and what it printed.
  JobRunFacts = Data.define(:status, :ago, :seconds, :output, :exit_status)

  class JobRunFacts
    DEFAULTS = { ago: 3600, seconds: 2, output: nil, exit_status: nil }.freeze

    def initialize(**given) = super(**DEFAULTS, **given)
  end

  def add_job(name, cadence)
    path = File.join(job_project, ".fun-ci", cadence, "#{name}.sh")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/sh\n")
    File.chmod(0o755, path)
  end

  # Records a run of `name` on `sha`, answering its id.
  def record_job_run(name, sha, facts, branch: "main")
    started = clock.now - facts.ago
    ended = facts.status == "running" ? nil : started + facts.seconds
    db.execute("INSERT INTO job_runs (project_path, job, cadence, commit_hash, branch, status, started_at, " \
               "completed_at, exit_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
               [job_project, name, cadence_of(name), sha, branch, facts.status, stamp(started), ended && stamp(ended),
                facts.exit_status])
    db.last_insert_row_id.tap { |id| keep_output(id, facts.output) }
  end

  private

  def cadence_of(name) = Dir.glob("*/#{name}.sh", base: File.join(job_project, ".fun-ci")).first.split("/").first
  def stamp(time) = time.utc.iso8601(3)

  def keep_output(id, output)
    return unless output

    document = FunCi::Evidence::Document.legacy(tail: output, failures: [])
    db.execute("UPDATE job_runs SET evidence = ?, output_tail = ? WHERE id = ?",
               [JSON.generate(document.to_h), output, id])
    FunCi::Persistence::RawOutputs.for_jobs(db.filename("main")).write(id, output)
  end
end
