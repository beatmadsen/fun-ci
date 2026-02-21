# frozen_string_literal: true

require "open3"
require "timeout"
require_relative "project_config"
require_relative "pipeline_recorder"
require_relative "background_wrapper"
require_relative "stage_runner"
require_relative "stale_pipeline_canceller"
require_relative "progress_reporter"
require_relative "pipeline_forker"

module FunCi
  class Trigger
    DEFAULT_BUDGETS = {
      "lint" => 30,
      "build" => 30,
      "fast" => 10,
      "slow" => 300
    }.freeze

    def self.run_from_args(args, stdout: $stdout, stderr: $stderr, recorder: NullRecorder.new, pipeline_forker: nil)
      positional = args.reject { |a| a.start_with?("--") }
      if positional.length < 2
        stderr.puts "fun-ci: commit hash and branch name are required."
        stderr.puts "Usage: fun-ci trigger <commit-hash> <branch>"
        return 1
      end
      commit_hash, branch = positional
      if args.include?("--no-validate")
        (pipeline_forker || PipelineForker.method(:fork_pipeline)).call(
          commit_hash: commit_hash, branch: branch, db_path: recorder.db_path
        )
        recorder.close
        return 0
      end
      new(project_root: Dir.pwd, commit_hash: commit_hash, branch: branch,
          stdout: stdout, stderr: stderr, recorder: recorder).run
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
      cancel_stale_pipelines
      @recorder.create_run(commit_hash: @commit_hash, branch: @branch)
      stage_runner = make_stage_runner
      progress = ProgressReporter.new(stdout: @stdout)
      results = run_phase_one(stage_runner, config)
      progress.phase_one_result(results)
      unless results.values.all?
        @recorder.fail_run
        return 1
      end
      spawn_slow_suite(config)
      progress.slow_launched
      fast_runner = make_stage_runner
      fast_passed = fast_runner.run_stage(config, "fast")
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

    def spawn_slow_suite(config)
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

    def make_stage_runner
      StageRunner.new(
        commit_hash: @commit_hash, stdout: @stdout,
        command_runner: @command_runner,
        time_budgets: @time_budgets, recorder: @recorder
      )
    end

    def cancel_stale_pipelines
      return unless @recorder.db
      StalePipelineCanceller.new(
        db: @recorder.db, branch: @branch, stdout: @stdout
      ).cancel(new_commit_hash: @commit_hash)
    end

    def default_background_launcher(db_path:, pipeline_run_id:, job_id:, executor:)
      @recorder.close
      pid = fork do
        recorder = DbRecorder.for_background(db_path, pipeline_run_id)
        BackgroundWrapper.new(recorder: recorder, job_id: job_id, executor: executor).run
        recorder.close
      end
      @recorder = DbRecorder.for_background(db_path, pipeline_run_id)
      Process.detach(pid)
      PipelineRun.store_pid(@recorder.db, pipeline_run_id, pid)
    end

    def default_commit_validator(commit_hash)
      _, status = Open3.capture2e("git", "cat-file", "-t", commit_hash)
      status.success?
    end
  end
end
