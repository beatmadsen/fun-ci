# frozen_string_literal: true

require_relative "../persistence/active_runs"
require_relative "slot_lock"

module FunCi
  module Pipeline
    # Stops every process of a run. The run's own processes go first, so none
    # of them records the run as failed once its stages die; then each stage's
    # process group. A run whose slot nobody holds any more has died already,
    # and the pids it recorded may belong to other processes now, so it is
    # left alone; so is this process.
    class RunCanceller
      def initialize(killer: Process.method(:kill), slot_held: SlotLock.method(:held?))
        @killer = killer
        @slot_held = slot_held
      end

      # Stops the run and records it, and its unfinished stages, cancelled.
      def cancel(db, run)
        stop(run)
        Persistence::ActiveRuns.cancelled(db, run)
      end

      def stop(run)
        return unless alive?(run)

        (run.processes - [Process.pid] + run.stage_groups.map(&:-@)).each { |pid| kill(pid) }
      end

      private

      def alive?(run) = run.slot_lock.nil? || @slot_held.call(run.slot_lock)

      def kill(pid)
        @killer.call("KILL", pid)
      rescue Errno::ESRCH
        nil
      end
    end
  end
end
