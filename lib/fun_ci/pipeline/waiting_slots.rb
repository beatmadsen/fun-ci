# frozen_string_literal: true

require "fileutils"
require_relative "slot_lock"

module FunCi
  module Pipeline
    # The slots held only by a slow suite waiting its branch's turn
    # (acceptance-tests.md, AT-9.19). Such a suite keeps its slot, whose
    # checkout and build it runs in, and holds an flock on the slot's mark
    # under `waiting/` beside the slots while it waits. WorktreePool hands out
    # a further slot for each mark held, so a queued suite keeps no other
    # branch's run waiting. A mark dies with the process that held it.
    module WaitingSlots
      DIR = "waiting"

      # The mark of the slot at `slot_path`, held until it is closed.
      def self.mark(slot_path)
        path = mark_path(slot_path)
        FileUtils.mkdir_p(File.dirname(path))
        File.new(path, File::RDWR | File::CREAT, 0o644).tap { |mark| mark.flock(File::LOCK_EX) }
      end

      # How many slots under `root` a waiting slow suite holds now.
      def self.count(root) = Dir.glob(File.join(root, DIR, "*.lock")).count { |path| SlotLock.held?(path) }

      def self.mark_path(slot_path) = File.join(File.dirname(slot_path), DIR, "#{File.basename(slot_path)}.lock")
    end
  end
end
