# frozen_string_literal: true

require "timeout"
require_relative "process_runner"

module FunCi
  module Pipeline
    # Runs a stage command within its budget and answers [output, status, timed_out].
    # An injected command runner replaces the real process and signals a blown
    # budget by raising Timeout::Error.
    class CommandExecutor
      include ProcessRunner

      def initialize(command_runner)
        @command_runner = command_runner
      end

      def call(cmd, budget)
        return run_process_with_timeout(cmd, budget) unless @command_runner

        output, status = @command_runner.call(cmd)
        [output, status, false]
      rescue Timeout::Error
        ["", nil, true]
      end
    end
  end
end
