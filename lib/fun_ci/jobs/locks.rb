# frozen_string_literal: true

require "fileutils"
require_relative "../pipeline/slot"

module FunCi
  module Jobs
    # Each job's worktree and the lock beside it, under a project's
    # <git-common-dir>/fun-ci/jobs: `<name>` and `<name>.lock`. Whoever holds
    # a job's lock runs it, so it runs once at a time, and a lock dies with
    # the process that held it.
    class Locks
      def initialize(root)
        @root = root
      end

      # The job's worktree, held through its lock as a Pipeline::Slot, or nil
      # while another process holds it.
      def take(name)
        FileUtils.mkdir_p(@root)
        path = File.join(@root, name)
        lock = File.new("#{path}.lock", File::RDWR | File::CREAT, 0o644)
        return Pipeline::Slot.new(path, lock, lock.path) if lock.flock(File::LOCK_EX | File::LOCK_NB)

        lock.close
        nil
      end
    end
  end
end
