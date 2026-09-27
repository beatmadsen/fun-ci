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

      def initialize(command_runner, dir = Dir.pwd)
        @command_runner = command_runner
        @dir = dir
      end

      # Yields the pid of the process the command runs in, when there is one.
      # `env` is added to the command's environment; an injected runner that
      # takes a second argument is given it.
      def call(cmd, budget, env: {}, &)
        return run_process_with_timeout(cmd, budget, launch: launch(env), &) unless @command_runner

        output, status = run_injected(cmd, env, &)
        [output, status, false]
      rescue Timeout::Error
        ["", nil, true]
      end

      private

      def launch(env) = Launch.new(chdir: @dir, env: env)

      # A lambda's own, or those of an object's #call.
      def parameters
        @command_runner.respond_to?(:parameters) ? @command_runner.parameters : @command_runner.method(:call).parameters
      end

      def run_injected(cmd, env, &)
        takes_env = parameters.count { |kind, _| %i[req opt].include?(kind) } > 1
        takes_env ? @command_runner.call(cmd, env, &) : @command_runner.call(cmd, &)
      end
    end
  end
end
