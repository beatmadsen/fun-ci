# frozen_string_literal: true

require "fileutils"
require_relative "slot"
require_relative "worktrees"

module FunCi
  module Pipeline
    # Hands each pipeline a worktree slot of its own under
    # <git-common-dir>/fun-ci/worktrees, checked out at its commit, waiting
    # while every slot is taken.
    class WorktreePool
      DEFAULT_SIZE = 2

      attr_reader :size

      def initialize(worktrees, size: DEFAULT_SIZE, waiter: -> { sleep 0.25 })
        @worktrees = worktrees
        @size = size
        @waiter = waiter
      end

      def acquire(sha)
        slot = wait_for_free_slot
        @worktrees.check_out(slot.path, sha)
        slot
      rescue StandardError
        slot&.release
        raise
      end

      private

      def wait_for_free_slot
        loop do
          slot = free_slot
          return slot if slot

          @waiter.call
        end
      end

      def free_slot
        root = @worktrees.root
        FileUtils.mkdir_p(root)
        @size.times.lazy.filter_map { |index| try_lock(File.join(root, "slot-#{index}")) }.first
      end

      # The lock stays open for as long as the slot is held, so no block.
      def try_lock(path)
        lock = File.new("#{path}.lock", File::RDWR | File::CREAT, 0o644)
        return Slot.new(path, stamped(lock), lock.path) if lock.flock(File::LOCK_EX | File::LOCK_NB)

        lock.close
        nil
      end

      def stamped(lock)
        lock.truncate(0)
        lock.write(Process.pid.to_s)
        lock.flush
        lock
      end
    end
  end
end
