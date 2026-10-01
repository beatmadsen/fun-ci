# frozen_string_literal: true

require_relative "job_run"
require_relative "../persistence/database"
require_relative "../pipeline/worktrees"
require_relative "../pipeline/priorities"

module FunCi
  module Jobs
    # Starts a job in a process of its own (architecture.md, Daily and weekly
    # jobs). The trigger that forks it exits when its pipeline ends, and the
    # terminal of the commit may close; a job can run for hours, so it leads a
    # session of its own, prints nowhere, and opens its own connection, since
    # a child must not inherit one. `priorities` says what its script runs under.
    class JobFork
      def initialize(project:, db_path:, priorities: Pipeline::Priorities.for(RUBY_PLATFORM))
        @project = project
        @db_path = db_path
        @priorities = priorities
      end

      def start(job, commit) = Process.detach(fork { run_in_child(job, commit) })

      private

      def run_in_child(job, commit)
        Process.setsid
        silence
        db = Persistence::Database.connection(@db_path)
        JobRun.new(job, commit, site(db), Pipeline::Seams.new(priorities: @priorities)).start
      ensure
        db&.close
      end

      # The process's own descriptors, whatever $stdout and $stderr stand for
      # (a test's StringIO, a guard's file), onto an open /dev/null, since
      # reopening by path can't change a stream's access mode.
      def silence
        File.open(File::NULL, File::RDWR) do |null|
          (0..2).each { |fd| IO.for_fd(fd, autoclose: false).reopen(null) }
        end
      end

      def site(db)
        worktrees = Pipeline::Worktrees.new(@project)
        Site.new(project: @project, db: db, worktrees: worktrees, locks: Locks.new(worktrees.jobs_root),
                 clock: -> { Time.now })
      end
    end
  end
end
