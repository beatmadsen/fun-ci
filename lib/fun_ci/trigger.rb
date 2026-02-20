# frozen_string_literal: true

require "open3"
require "timeout"
require_relative "project_config"
require_relative "pipeline_recorder"
require_relative "background_wrapper"
require_relative "stage_runner"
require_relative "stale_pipeline_canceller"
require_relative "progress_reporter"

module FunCi
  class Trigger
    DEFAULT_BUDGETS = {
      "lint" => 30,
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
      return handle_config_errors(config) if config.validate.any?
      unless @commit_validator.call(@commit_hash)
        @stderr.puts "fun-ci: commit #{@commit_hash} not found in this repository."
        return 1
      end
      canceller = StalePipelineCanceller.new(
        project_root: @project_root, branch: @branch,
        commit_hash: @commit_hash, stdout: @stdout
      )
      canceller.cancel
      @recorder.create_run(commit_hash: @commit_hash, branch: @branch)

      stage_runner = StageRunner.new(
        commit_hash: @commit_hash, stdout: @stdout,
        command_runner: @command_runner,
        time_budgets: @time_budgets, recorder: @recorder
      )
      progress = ProgressReporter.new(stdout: @stdout)

      # Phase 1: lint + build in parallel
      results = run_phase_one(stage_runner, config)
      progress.phase_one_result(results)
      unless results.values.all?
        @recorder.fail_run
        return 1
      end
      # Phase 2: slow (background) + fast (blocking)
      spawn_slow_suite(config, canceller)
      progress.slow_launched
      fast_passed = stage_runner.run_stage(config, "fast")
      progress.fast_result(fast_passed)
      unless fast_passed
        @recorder.fail_run
        return 1
      end

      0
    end

    private

    def handle_config_errors(config)
      config.validate.each { |e| @stdout.puts "fun-ci: #{e}" }
      unless config.folder_exists?
        @stdout.puts "Create .fun-ci/lint.sh, build.sh, fast.sh, and slow.sh to set up this project."
        @stdout.puts "Commit will proceed without CI."
      end
      0
    end

    def run_phase_one(stage_runner, config)
      results = {}
      threads = %w[lint build].map do |stage|
        Thread.new { results[stage] = stage_runner.run_stage(config, stage) }
      end
      threads.each(&:join)
      results
    end

    def spawn_slow_suite(config, canceller)
      cmd = "#{config.script_path("slow")} #{@commit_hash}"
      job_id = @recorder.start_stage("slow")
      runner = @command_runner || ->(c) { Open3.capture2e(c) }
      budget = @time_budgets["slow"]
      executor = -> { Timeout.timeout(budget) { runner.call(cmd) } }
      @background_launcher.call(
        db_path: @recorder.db_path, pipeline_run_id: @recorder.pipeline_run_id,
        job_id: job_id, executor: executor
      )
    end

    def default_background_launcher(db_path:, pipeline_run_id:, job_id:, executor:)
      @recorder.close
      canceller = StalePipelineCanceller.new(
        project_root: @project_root, branch: @branch,
        commit_hash: @commit_hash, stdout: @stdout
      )
      pid = fork do
        recorder = DbRecorder.for_background(db_path, pipeline_run_id)
        BackgroundWrapper.new(recorder: recorder, job_id: job_id, executor: executor).run
        recorder.close
      end
      Process.detach(pid)
      canceller.write_pid_file(pid)
    end

    def default_commit_validator(commit_hash)
      _, status = Open3.capture2e("git", "cat-file", "-t", commit_hash)
      status.success?
    end
  end
end
