# frozen_string_literal: true

require_relative "../persistence/active_runs"
require_relative "../persistence/run_status"
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

      # Records failed each slow stage whose forked process is gone without
      # having recorded its result (acceptance-tests.md, AT-8.3), and settles
      # its run.
      def record_dead(db)
        Persistence::ActiveRuns.slow_suites(db).reject { |_, _, pid| exists?(pid) }.each do |job_id, run_id, _|
          Persistence::StageJob.update_status(db, job_id, "failed")
          Persistence::RunStatus.settle(db, run_id)
        end
      end

      def stop(run)
        return unless alive?(run)

        (run.processes - [Process.pid] + run.stage_groups.map(&:-@)).each { |pid| kill(pid) }
      end

      private

      def alive?(run) = run.slot_lock.nil? || @slot_held.call(run.slot_lock)

      # Whether a process with this pid exists; one this user may not signal does.
      def exists?(pid)
        @killer.call(0, pid)
        true
      rescue Errno::ESRCH
        false
      rescue Errno::EPERM
        true
      end

      def kill(pid)
        @killer.call("KILL", pid)
      rescue Errno::ESRCH
        nil
      end
    end
  end
end
