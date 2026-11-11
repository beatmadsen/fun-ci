# frozen_string_literal: true

require "fileutils"
require_relative "slot_lock"

module FunCi
  module Pipeline
    # A slow suite's place among its branch's: where its run's commit arrived
    # (Persistence::Arrival), then its stage's id, so of two runs of one
    # commit the later is the newer.
    TurnTicket = Data.define(:place, :id) do
      def name = format("%<place>020d-%<id>020d.lock", place: place, id: id)
    end

    # The tickets of a branch's slow suites waiting or running, as files in
    # `dir`, each holding an flock on its own until its turn is over. A ticket
    # appears already held (locked under a name of its own, then renamed), so
    # one nobody holds was left by a suite that died, and goes.
    class TurnQueue
      # Blocks until the suite holding the ticket at each of `paths` is done.
      WAIT = ->(paths) { paths.each { |path| TurnQueue.wait_on(path) } }

      def self.wait_on(path)
        File.open(path) { |file| file.flock(File::LOCK_SH) }
      rescue Errno::ENOENT
        nil
      end

      def initialize(dir)
        @dir = dir
      end

      # Holds `ticket` in the queue until the block returns.
      def holding(ticket)
        path = File.join(@dir, ticket.name)
        file = enter(path)
        yield
      ensure
        FileUtils.rm_f(path) if file
        file&.close
      end

      # The tickets held of suites newer than `ticket`'s.
      def newer_than(ticket)
        Dir.glob(File.join(@dir, "*.lock")).select { |path| live?(path) && File.basename(path) > ticket.name }
      end

      private

      def enter(path)
        FileUtils.mkdir_p(@dir)
        locked("#{path}.#{Process.pid}.new").tap { |file| File.rename(file.path, path) }
      end

      def locked(path) = File.new(path, File::RDWR | File::CREAT, 0o644).tap { |file| file.flock(File::LOCK_EX) }

      def live?(path)
        return true if SlotLock.held?(path)

        FileUtils.rm_f(path)
        false
      end
    end
  end
end
