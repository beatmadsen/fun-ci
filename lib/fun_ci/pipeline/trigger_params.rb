# frozen_string_literal: true

require "open3"
require_relative "../persistence/pipeline_recorder"
require_relative "command_executor"
require_relative "stage_dir"
require_relative "git_environment"
require_relative "priorities"
require_relative "../evidence/command_runner"
require_relative "../evidence/process_table"

module FunCi
  module Pipeline
    DEFAULT_BUDGETS = { "lint" => 30, "build" => 30, "fast" => 10, "slow" => 300 }.freeze

    Commit = Data.define(:sha, :branch)

    # On a detached HEAD git names no branch, and the hooks pass "": the run
    # is kept, shown and cancelled by others on the branch "detached".
    class Commit
      DETACHED = "detached"

      def initialize(sha:, branch:) = super(sha: sha, branch: branch.empty? ? DETACHED : branch)
    end

    Io = Data.define(:stdout, :stderr) do
      def initialize(stdout: $stdout, stderr: $stderr) = super
    end

    # The collaborators a pipeline run can have replaced. Each one left out
    # gets the real thing. `environment` is the stages' environment as a hash,
    # which masking and injected command runners see; `clock` answers seconds
    # for the evidence budget; `extractor_runner` makes what runs a project's
    # own extractors (`run:` entries), given dir:, env: and scratch:;
    # `process_table` answers what ps lists, for a stage over budget; `trunk`
    # checks a commit against the trunk (#check(sha) answers a Trunk::Check,
    # or nil for no check), nil for the project's own; `priorities` what jobs
    # and the slow suite start under.
    Seams = Data.define(:command_runner, :time_budgets, :commit_validator, :recorder, :background_launcher, :workspace,
                        :stage_dir, :environment, :clock, :extractor_runner, :process_table, :trunk, :priorities)

    # Reopened rather than given as a block to Data.define, so tools that read
    # the source (mutineer) see these as Seams' methods.
    class Seams
      def self.defaults
        { command_runner: nil, time_budgets: {}, recorder: Persistence::NullRecorder.new, background_launcher: nil,
          workspace: nil, commit_validator: method(:commit_exists?), stage_dir: StageDir.method(:create),
          environment: ENV.to_h, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
          extractor_runner: Evidence::CommandRunner.method(:new),
          process_table: Evidence::ProcessTable.method(:now), trunk: nil, priorities: Priorities.for(RUBY_PLATFORM) }
      end

      def self.commit_exists?(sha) = Open3.capture2e(GitEnvironment::CLEAN, "git", "cat-file", "-t", sha).last.success?

      def initialize(**given) = super(**self.class.defaults.merge(given))
      def budgets = DEFAULT_BUDGETS.merge(time_budgets)
      def executor(dir) = CommandExecutor.new(command_runner, dir, environment)
    end
  end
end
