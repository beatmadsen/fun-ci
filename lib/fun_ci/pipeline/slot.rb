# frozen_string_literal: true

module FunCi
  module Pipeline
    # A worktree a pipeline has to itself, held through an flock on its lock
    # file. The fast suite and the slow suite each hold it; it frees when the
    # last of them lets go. A process that dies lets go with it.
    class Slot
      attr_reader :path, :lock_file

      # +lock_file+ names the lock on disk; nil for a slot with nothing to lock.
      def initialize(path, lock, lock_file = nil)
        @path = path
        @lock = lock
        @lock_file = lock_file
        @holders = 1
      end

      def share
        @holders += 1
        self
      end

      def release
        @holders -= 1
        @lock.close if @holders.zero? && !@lock.closed?
      end
    end
  end
end
