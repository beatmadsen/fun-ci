# frozen_string_literal: true

require "fileutils"
require "fun_ci/persistence/job_recorder"
require "fun_ci/evidence/document"
require "fun_ci/jobs/job"

# Daily and weekly jobs for the agent commands' tests: a job's script in the
# project, and its runs as JobRun records them, at times the test chooses.
# The row is inserted here, since a claim refuses a run that isn't due and a
# run's end takes the wall clock; all else is written by the real
# JobRecorder. Expects #db, #clock and a project directory from #job_project.
module JobRecording
  # A run's facts: status as job_runs keeps it, when it started (seconds before
  # the clock's now), how long it ran, and what it printed.
  # `extractor` names what kept the output's excerpt; `budget` is nil for a
  # run kept before job runs had one.
  JobRunFacts = Data.define(:status, :ago, :seconds, :output, :exit_status, :extractor, :budget)

  class JobRunFacts
    DEFAULTS = { ago: 3600, seconds: 2, output: nil, exit_status: nil, extractor: "output-tail",
                 budget: FunCi::Jobs::Job::BUDGET }.freeze

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
    ended = facts.status == "running" || facts.seconds.nil? ? nil : started + facts.seconds
    db.execute("INSERT INTO job_runs (project_path, job, cadence, commit_hash, branch, status, started_at, " \
               "completed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
               [job_project, name, cadence_of(name), sha, branch, facts.status, stamp(started), ended && stamp(ended)])
    db.last_insert_row_id.tap { |id| record_ending(id, facts) }
  end

  private

  def cadence_of(name) = Dir.glob("*/#{name}.sh", base: File.join(job_project, ".fun-ci")).first.split("/").first
  def stamp(time) = time.utc.iso8601(3)

  def record_ending(id, facts)
    recorder = FunCi::Persistence::JobRecorder.new(db)
    recorder.started_by(id, nil, budget: facts.budget)
    recorder.keep_exit(id, facts.exit_status, nil)
    keep_output(recorder, id, facts) if facts.output
  end

  def keep_output(recorder, id, facts)
    tail = FunCi::Evidence::Document.legacy(tail: facts.output, failures: [])
    excerpts = tail.excerpts.map { |excerpt| excerpt.merge(extractor: facts.extractor) }
    recorder.keep_evidence(id, tail.with(excerpts: excerpts))
    recorder.keep_raw(id, facts.output)
  end
end
