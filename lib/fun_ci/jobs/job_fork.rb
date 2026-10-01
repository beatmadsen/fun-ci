# frozen_string_literal: true

require_relative "job_run"
require_relative "../persistence/database"

module FunCi
  module Jobs
    # Starts a job in a process of its own (architecture.md, Daily and weekly
    # jobs). The trigger that forks it exits when its pipeline ends, and the
    # terminal of the commit may close; a job can run for hours, so it leads a
    # session of its own, prints nowhere, and opens its own connection, since
    # a child must not inherit one.
    module JobFork
      def self.start(job, commit, project:, db_path:)
        Process.detach(fork { run_in_child(job, commit, project, db_path) })
      end

      def self.run_in_child(job, commit, project, db_path)
        Process.setsid
        silence
        db = Persistence::Database.connection(db_path)
        JobRun.new(job, commit, site(project, db), Pipeline::Seams.new).start
      ensure
        db&.close
      end

      # The process's own descriptors, whatever $stdout and $stderr stand for
      # (a test's StringIO, a guard's file), onto an open /dev/null, since
      # reopening by path can't change a stream's access mode.
      def self.silence
        File.open(File::NULL, File::RDWR) do |null|
          (0..2).each { |fd| IO.for_fd(fd, autoclose: false).reopen(null) }
        end
      end

      def self.site(project, db)
        worktrees = Pipeline::Worktrees.new(project)
        Site.new(project: project, db: db, worktrees: worktrees, locks: Locks.new(worktrees.jobs_root),
                 clock: -> { Time.now })
      end
      private_class_method :run_in_child, :silence, :site
    end
  end
end
