# frozen_string_literal: true

require "digest"
require "fileutils"
require_relative "turn_queue"

module FunCi
  module Pipeline
    # The turns a branch's slow suites take: one runs at a time, and of those
    # waiting, the one whose commit arrived last goes next (acceptance-tests.md,
    # AT-9.19, AT-9.20). A turn is an flock on the branch's file under `root`,
    # and each suite holds a ticket in the branch's TurnQueue while it waits and
    # runs, so both end with the process that held them, a slow suite cancelled
    # while it waits included.
    class SlowTurns
      # The most passes taking a turn makes. Each but the last lets a newer
      # suite run to its end, so this covers more than a branch queues; it
      # stops a pass that never ends, as a mutant's, all the same.
      ROUNDS = 100

      # wait: called once each pass with the paths of the newer suites'
      # tickets to let go first, none on the last; blocks until those are done.
      def initialize(root, wait: TurnQueue::WAIT)
        @root = root
        @wait = wait
      end

      # Yields once no other process holds the branch's turn and no newer
      # suite of the branch waits for it, holding the turn until the block returns.
      def take(branch, ticket)
        queue = TurnQueue.new(queue_dir(branch))
        queue.holding(ticket) do
          File.open(lock_path(branch), File::RDWR | File::CREAT, 0o644) do |lock|
            in_order(queue, ticket, lock)
            yield
          end
        end
      end

      def lock_path(branch) = File.join(@root, "#{digest(branch)}.lock")
      def ticket_path(branch, ticket) = File.join(queue_dir(branch), ticket.name)

      private

      # Each newer suite goes first; with the turn held it looks again, as a
      # newer one may have come meanwhile. A wait ends only once its ticket's
      # holder let go, so each ticket is waited for once: one that still seems
      # held is no live suite's, and the passes end with the tickets seen.
      def in_order(queue, ticket, lock)
        waited = Set.new
        ROUNDS.times do
          waited.merge(let_go(queue.newer_than(ticket) - waited))
          return if turn_taken?(queue, ticket, lock, waited)
        end
        lock.flock(File::LOCK_EX)
      end

      # Takes the turn, and whether no suite newer than those `waited` for
      # came meanwhile; lets the turn go again if one did.
      def turn_taken?(queue, ticket, lock, waited)
        lock.flock(File::LOCK_EX)
        return true if (queue.newer_than(ticket) - waited).empty?

        lock.flock(File::LOCK_UN)
        false
      end

      def let_go(tickets) = tickets.tap { @wait.call(tickets) }

      def queue_dir(branch) = File.join(@root, digest(branch))
      def digest(branch) = Digest::SHA256.hexdigest(branch)[0, 16]
    end
  end
end
