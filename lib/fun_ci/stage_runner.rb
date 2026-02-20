# frozen_string_literal: true

require "open3"
require "timeout"

module FunCi
  class StageRunner
    def initialize(commit_hash:, stdout:, command_runner: nil, time_budgets: {}, recorder: NullRecorder.new)
      @commit_hash = commit_hash
      @stdout = stdout
      @command_runner = command_runner
      @time_budgets = time_budgets
      @recorder = recorder
    end

    def run_stage(config, stage)
      script = config.script_path(stage)
      budget = @time_budgets[stage]

      job_id = @recorder.start_stage(stage)
      output, status, timed_out = run_with_timeout(script, budget)

      if timed_out
        @recorder.end_stage(job_id, "timed_out")
        @stdout.puts "#{stage_label(stage)} killed -- exceeded #{budget}s time budget."
        @stdout.puts budget_advice(stage)
        return false
      end

      unless status.success?
        @recorder.end_stage(job_id, "failed")
        @stdout.puts output unless output.empty?
        @stdout.puts "#{stage_label(stage)} failed."
        return false
      end

      @recorder.end_stage(job_id, "completed")
      true
    end

    private

    def run_with_timeout(script, budget)
      cmd = "#{script} #{@commit_hash}"

      if @command_runner
        begin
          Timeout.timeout(budget) do
            output, status = @command_runner.call(cmd)
            [output, status, false]
          end
        rescue Timeout::Error
          ["", nil, true]
        end
      else
        run_process_with_timeout(cmd, budget)
      end
    end

    def run_process_with_timeout(cmd, budget)
      pid = nil
      output = ""
      r, w = IO.pipe
      pid = Process.spawn(cmd, out: w, err: w)
      w.close

      begin
        Timeout.timeout(budget) do
          output = r.read
          _, status = Process.waitpid2(pid)
          pid = nil
          [output, status, false]
        end
      rescue Timeout::Error
        Process.kill("TERM", pid) rescue nil
        Process.kill("KILL", pid) rescue nil
        Process.waitpid(pid) rescue nil
        r.close rescue nil
        ["", nil, true]
      ensure
        r.close rescue nil
      end
    end

    def stage_label(stage)
      case stage
      when "lint" then "Lint"
      when "build" then "Build"
      when "fast" then "Fast suite"
      when "slow" then "Slow suite"
      else stage
      end
    end

    def budget_advice(stage)
      case stage
      when "lint"
        "Trim your linter config or split into stages."
      when "build"
        "Keep your build efficient and not let it become a bottleneck."
      when "fast"
        "Your fast tests have gotten too slow. Split or speed them up."
      when "slow"
        "Pare down integration tests, parallelise, or raise the budget."
      end
    end
  end
end
