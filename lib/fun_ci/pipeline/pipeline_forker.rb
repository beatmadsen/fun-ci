# frozen_string_literal: true

require_relative "../persistence/database"
require_relative "../persistence/pipeline_recorder"
require_relative "trigger_params"
require_relative "../setup/project_config"
require_relative "../trunk/first_fetch"
require_relative "../jobs/due_jobs"
require_relative "../jobs/job_fork"

module FunCi
  module Pipeline
    class PipelineForker
      # A run started, what to say before the project's first fetch of its
      # trunk, if this is it, and why the daily and weekly jobs didn't start,
      # if they didn't.
      Forked = Data.define(:notice, :jobs)

      class Forked
        def initialize(notice:, jobs: nil) = super
      end

      # Answers a Forked, or false in a project not set up for fun-ci. What the
      # run prints goes nowhere, so the notice is worked out here, before the
      # fork. The project's due jobs start beside the run, each in a process
      # of its own (design.md, Daily and weekly jobs), once the run has
      # started, and trouble starting them never stops it. jobs: what starts
      # them, given the commit and the database's path.
      def self.fork_pipeline(commit_hash:, branch:, db_path:, jobs: method(:start_due_jobs))
        return false unless Setup::ProjectConfig.new(Dir.pwd).validate.empty?

        notice = first_fetch(db_path)
        Process.detach(fork { run_in_child(commit_hash: commit_hash, branch: branch, db_path: db_path) })
        Forked.new(notice: notice, jobs: trouble { jobs.call(Commit.new(sha: commit_hash, branch: branch), db_path) })
      end

      # What went wrong starting the jobs, or nil.
      def self.trouble
        yield
        nil
      rescue StandardError => e
        "fun-ci: the daily and weekly jobs didn't start: #{e.message}"
      end

      # The connection closes before the fork, which must not inherit it.
      def self.first_fetch(db_path)
        db = Persistence::Database.connection(db_path)
        Trunk::FirstFetch.notice(Dir.pwd, db)
      ensure
        db&.close
      end

      # Which jobs are due is read before any fork, which must not inherit the connection.
      def self.start_due_jobs(commit, db_path)
        due_jobs(db_path).each { |job| Jobs::JobFork.start(job, commit, project: Dir.pwd, db_path: db_path) }
      end

      def self.due_jobs(db_path)
        db = Persistence::Database.connection(db_path)
        Jobs::DueJobs.new(Dir.pwd, db, now: Time.now).list
      ensure
        db&.close
      end

      # Trigger requires this file, through TriggerCommand, so it is loaded
      # here, where it is used, rather than above.
      def self.run_in_child(commit_hash:, branch:, db_path:)
        require_relative "trigger"
        recorder = Persistence::DbRecorder.new(Persistence::Database.connection(db_path))
        trigger = trigger(commit_hash, branch, recorder)
        trigger.run
        trigger.close
      end

      # The slow suite forks from here as it does in the foreground, so the
      # fast suite, whose verdict a push waits for, runs beside it.
      def self.trigger(commit_hash, branch, recorder)
        Trigger.new(project: Dir.pwd, commit: Commit.new(sha: commit_hash, branch: branch),
                    io: Io.new(stdout: File.open(File::NULL, "w")), seams: Seams.new(recorder: recorder))
      end
      private_class_method :trigger, :first_fetch, :start_due_jobs, :due_jobs, :trouble
    end
  end
end
