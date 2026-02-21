# frozen_string_literal: true

require_relative "pipeline_run"

module FunCi
  class StalePipelineCanceller
    def initialize(db:, branch:, stdout:, process_killer: nil)
      @db = db
      @branch = branch
      @stdout = stdout
      @process_killer = process_killer || method(:default_process_killer)
    end

    def cancel(new_commit_hash:)
      run = PipelineRun.find_running_with_pid(@db, @branch)
      return unless run

      kill_process(run[:pid])
      PipelineRun.update_status(@db, run[:id], "cancelled")
      @stdout.puts "Cancelled stale pipeline for #{run[:commit_hash]}. Starting fresh for #{new_commit_hash}."
    end

    def store_pid(run_id, pid)
      PipelineRun.store_pid(@db, run_id, pid)
    end

    private

    def kill_process(pid)
      @process_killer.call(0, pid)
      safe_signal("TERM", pid)
      safe_signal("KILL", pid)
      begin
        Process.waitpid(pid)
      rescue Errno::ECHILD, Errno::ESRCH # rubocop:disable Lint/SuppressedException
      end
    rescue Errno::ESRCH
      # Process already dead
    end

    def safe_signal(signal, pid)
      @process_killer.call(signal, pid)
    rescue Errno::ESRCH
      # Already dead
    end

    def default_process_killer(signal, pid)
      Process.kill(signal, pid)
    end
  end
end
