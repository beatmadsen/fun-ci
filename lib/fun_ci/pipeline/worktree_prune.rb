# frozen_string_literal: true

require "fileutils"
require_relative "worktrees"

module FunCi
  module Pipeline
    # Removes every slot of a project's worktree pool, and git's entries for
    # them, when no run holds one. It takes each slot's lock first, so a run
    # starting meanwhile waits until the slot is gone and then checks it out
    # afresh.
    class WorktreePrune
      class Busy < StandardError; end

      def initialize(worktrees)
        @worktrees = worktrees
      end

      # How many slots it removed. Raises Busy, removing nothing, while a run
      # holds a slot.
      def run
        locks = take_locks
        locks.each { |lock| FileUtils.rm_rf(lock.path.delete_suffix(".lock")) }
        @worktrees.prune
        locks.size
      ensure
        locks&.each(&:close)
      end

      private

      # Every slot's lock, or none: on the first slot a run holds, it lets go
      # of the locks it took before raising Busy.
      def take_locks
        slot_paths.each_with_object([]) do |path, locks|
          locks << lock(path)
        rescue Busy
          locks.each(&:close)
          raise
        end
      end

      def slot_paths
        Dir.glob(File.join(@worktrees.root, "slot-*")).map { |path| path.delete_suffix(".lock") }.uniq
      end

      def lock(path)
        lock = File.new("#{path}.lock", File::RDWR | File::CREAT, 0o644)
        return lock if lock.flock(File::LOCK_EX | File::LOCK_NB)

        lock.close
        raise Busy, "a pipeline is running in #{path}"
      end
    end
  end
end
