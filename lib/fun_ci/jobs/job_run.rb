# frozen_string_literal: true

require_relative "folders"
require_relative "locks"
require_relative "site"
require_relative "../persistence/job_runs"
require_relative "../persistence/job_recorder"
require_relative "../pipeline/stage_execution"
require_relative "../pipeline/trigger_params"
require_relative "../evidence/document"

module FunCi
  module Jobs
    # One run of a job, in the process that runs it (design.md, Daily and
    # weekly jobs): with the job's lock held, a run left running is known to
    # be dead and is recorded failed, then the run is claimed if the job is
    # due, and the job runs on the commit in its own worktree, recorded as a
    # stage is.
    class JobRun
      def initialize(job, commit, site, seams)
        @job = job
        @commit = commit
        @site = site
        @seams = seams
      end

      # The run's id, or nil when another process runs the job or it isn't due.
      def start
        slot = @site.locks.take(@job.name)
        slot && holding(slot) { claimed(slot) }
      end

      private

      def runs = Persistence::JobRuns.new(@site.db, @site.project)
      def recorder = Persistence::JobRecorder.new(@site.db)

      def holding(slot)
        yield
      ensure
        slot.release
      end

      def claimed(slot)
        runs.died(@job.name)
        id = runs.claim(@job, commit: @commit.to_h, lock_file: slot.lock_file, now: @site.clock.call)
        id && execute(slot, id)
      end

      def execute(slot, id)
        recorder.started_by(id, Process.pid)
        @site.worktrees.check_out(slot.path, @commit.sha)
        execution(slot).run(@job.stage, command(slot.path), recorder, id)
        id
      rescue StandardError => e
        failed(id, e.message)
      end

      # The script holds the job's lock too, so the job reads as alive while
      # any of it runs, its runner gone or not.
      def execution(slot)
        seams = @seams.with(time_budgets: { @job.stage => Job::BUDGET }.merge(@seams.time_budgets))
        Pipeline::StageExecution.new(seams: seams, dir: slot.path, commit: @commit,
                                     launching: { env: { "FUN_CI_JOB" => @job.name }, held: [slot.lock] })
      end

      # The commit's own copy of the script when it has one, as a pipeline's stages are.
      def command(dir)
        committed = File.join(dir, ".fun-ci", @job.cadence, "#{@job.name}.sh")
        (File.exist?(committed) ? @job.with(script: committed) : @job).command(@commit.sha)
      end

      # Whatever stopped the run, so it isn't left running: a run left running
      # is only found dead once its lock is free, and then says nothing of why.
      def failed(id, problem)
        recorder.keep_evidence(id, Evidence::Document.broken(problem))
        recorder.end_stage(id, "failed")
        id
      end
    end
  end
end
