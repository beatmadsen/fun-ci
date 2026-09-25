# frozen_string_literal: true

require "open3"
require_relative "../persistence/pipeline_recorder"
require_relative "command_executor"
require_relative "git_environment"

module FunCi
  module Pipeline
    DEFAULT_BUDGETS = { "lint" => 30, "build" => 30, "fast" => 10, "slow" => 300 }.freeze

    Commit = Data.define(:sha, :branch)

    Io = Data.define(:stdout, :stderr) do
      def initialize(stdout: $stdout, stderr: $stderr) = super
    end

    # The collaborators a pipeline run can have replaced. Each one left out
    # gets the real thing.
    Seams = Data.define(:command_runner, :time_budgets, :commit_validator, :recorder, :background_launcher, :workspace)

    # Reopened rather than given as a block to Data.define, so tools that read
    # the source (mutineer) see these as Seams' methods.
    class Seams
      def self.defaults
        { command_runner: nil, time_budgets: {}, recorder: Persistence::NullRecorder.new, background_launcher: nil,
          workspace: nil, commit_validator: method(:commit_exists?) }
      end

      def self.commit_exists?(sha) = Open3.capture2e(GitEnvironment::CLEAN, "git", "cat-file", "-t", sha).last.success?

      def initialize(**given) = super(**self.class.defaults.merge(given))
      def budgets = DEFAULT_BUDGETS.merge(time_budgets)
      def executor(dir) = CommandExecutor.new(command_runner, dir)
    end
  end
end
