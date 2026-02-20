# frozen_string_literal: true

require "open3"
require "timeout"
require_relative "project_config"
require_relative "pipeline_recorder"
require_relative "background_wrapper"

module FunCi
  class Trigger
    DEFAULT_BUDGETS = {
      "build" => 30,
      "fast" => 10,
      "slow" => 300
    }.freeze

    def self.run_from_args(args, stdout: $stdout, stderr: $stderr, recorder: NullRecorder.new)
      if args.length < 2
        stderr.puts "fun-ci: commit hash and branch name are required."
        stderr.puts "Usage: fun-ci trigger <commit-hash> <branch>"
        return 1
      end

      commit_hash, branch = args
      new(
        project_root: Dir.pwd,
        commit_hash: commit_hash,
        branch: branch,
        stdout: stdout,
        stderr: stderr,
        recorder: recorder
      ).run
    end

    attr_writer :command_runner

    def initialize(project_root:, commit_hash:, branch:, stdout: $stdout, stderr: $stderr, command_runner: nil, time_budgets: {}, commit_validator: nil, recorder: NullRecorder.new, background_launcher: nil)
      @project_root = project_root
      @commit_hash = commit_hash
      @branch = branch
      @stdout = stdout
      @stderr = stderr
      @command_runner = command_runner
      @time_budgets = DEFAULT_BUDGETS.merge(time_budgets)
      @commit_validator = commit_validator || method(:default_commit_validator)
      @recorder = recorder
      @background_launcher = background_launcher || method(:default_background_launcher)
    end

    def run
      config = ProjectConfig.new(@project_root)
      errors = config.validate

      if errors.any?
        errors.each { |e| @stdout.puts "fun-ci: #{e}" }
        unless config.folder_exists?
          @stdout.puts "Create .fun-ci/build.sh, fast.sh, and slow.sh to set up this project."
          @stdout.puts "Commit will proceed without CI."
        end
        return 0
      end

      unless @commit_validator.call(@commit_hash)
        @stderr.puts "fun-ci: commit #{@commit_hash} not found in this repository."
        return 1
      end

      cancel_stale_pipeline
      @recorder.create_run(commit_hash: @commit_hash, branch: @branch)

      unless run_stage(config, "build")
        @recorder.fail_run
        return 1
      end

      unless run_stage(config, "fast")
        @recorder.fail_run
        return 1
      end

      spawn_slow_suite(config)

      0
    end

    private

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

    def cancel_stale_pipeline
      pid_file = pid_file_path
      return unless File.exist?(pid_file)

      old_pid, old_commit = File.read(pid_file).strip.split("\n")
      old_pid = old_pid.to_i
      return if old_pid <= 0

      begin
        Process.kill(0, old_pid)
      rescue Errno::ESRCH
        File.delete(pid_file) rescue nil
        return
      end

      Process.kill("TERM", old_pid) rescue nil
      Process.kill("KILL", old_pid) rescue nil
      Process.waitpid(old_pid) rescue nil
      File.delete(pid_file) rescue nil

      @stdout.puts "Cancelled stale pipeline for #{old_commit}. Starting fresh for #{@commit_hash}."
    end

    def spawn_slow_suite(config)
      script = config.script_path("slow")
      cmd = "#{script} #{@commit_hash}"
      budget = @time_budgets["slow"]
      job_id = @recorder.start_stage("slow")

      runner = @command_runner || ->(c) { Open3.capture2e(c) }
      executor = -> { Timeout.timeout(budget) { runner.call(cmd) } }

      @background_launcher.call(
        db_path: @recorder.db_path,
        pipeline_run_id: @recorder.pipeline_run_id,
        job_id: job_id,
        executor: executor
      )
    end

    def pid_file_path
      pid_dir = File.join(@project_root, ".fun-ci-pids")
      Dir.mkdir(pid_dir) unless Dir.exist?(pid_dir)
      File.join(pid_dir, "#{@branch}.pid")
    end

    def write_pid_file(pid)
      File.write(pid_file_path, "#{pid}\n#{@commit_hash}")
    end

    def stage_label(stage)
      case stage
      when "build" then "Build"
      when "fast" then "Fast suite"
      when "slow" then "Slow suite"
      else stage
      end
    end

    def budget_advice(stage)
      case stage
      when "build"
        "Keep your build efficient and not let it become a bottleneck."
      when "fast"
        "Your fast tests have gotten too slow. Split or speed them up."
      when "slow"
        "Pare down integration tests, parallelise, or raise the budget."
      end
    end

    def default_background_launcher(db_path:, pipeline_run_id:, job_id:, executor:)
      @recorder.close
      pid = fork do
        recorder = DbRecorder.for_background(db_path, pipeline_run_id)
        BackgroundWrapper.new(recorder: recorder, job_id: job_id, executor: executor).run
        recorder.close
      end
      Process.detach(pid)
      write_pid_file(pid)
    end

    def default_commit_validator(commit_hash)
      _, status = Open3.capture2e("git", "cat-file", "-t", commit_hash)
      status.success?
    end
  end
end
