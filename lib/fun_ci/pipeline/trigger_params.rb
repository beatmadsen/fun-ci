# frozen_string_literal: true

require "open3"
require_relative "../persistence/pipeline_recorder"
require_relative "command_executor"

module FunCi
  module Pipeline
    DEFAULT_BUDGETS = { "lint" => 30, "build" => 30, "fast" => 10, "slow" => 300 }.freeze

    Commit = Data.define(:sha, :branch)

    Io = Data.define(:stdout, :stderr) do
      def initialize(stdout: $stdout, stderr: $stderr) = super
    end

    # The collaborators a pipeline run can have replaced. Each one left out
    # gets the real thing.
    Seams = Data.define(:command_runner, :time_budgets, :commit_validator, :recorder, :background_launcher) do
      def self.defaults
        { command_runner: nil, time_budgets: {}, recorder: Persistence::NullRecorder.new, background_launcher: nil,
          commit_validator: ->(sha) { Open3.capture2e("git", "cat-file", "-t", sha).last.success? } }
      end

      def initialize(**given) = super(**self.class.defaults.merge(given))
      def budgets = DEFAULT_BUDGETS.merge(time_budgets)
      def executor = CommandExecutor.new(command_runner)
    end
  end
end
