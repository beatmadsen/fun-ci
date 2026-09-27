# frozen_string_literal: true

require "timeout"
require_relative "process_runner"

module FunCi
  module Pipeline
    # Runs a stage command within its budget and answers [output, status, timed_out].
    # An injected command runner replaces the real process and signals a blown
    # budget by raising Timeout::Error. A real process inherits fun-ci's own
    # environment; an injected runner sees `environment` in its place.
    class CommandExecutor
      include ProcessRunner

      def initialize(command_runner, dir = Dir.pwd, environment = {})
        @command_runner = command_runner
        @dir = dir
        @environment = environment
      end

      # Yields the pid of the process the command runs in, when there is one.
      # `env` is added to the command's environment; an injected runner that
      # takes a second argument is given the whole of it. What the command
      # prints is written to `output`, and answered as the window keeps it.
      def call(cmd, budget, env: {}, output: OutputWindow.in_memory, &)
        launch = Launch.new(chdir: @dir, env: env, output: output)
        return run_process_with_timeout(cmd, budget, launch: launch, &) unless @command_runner

        printed, status = run_injected(cmd, env, &)
        [text(output << printed), status, false]
      rescue Timeout::Error
        ["", nil, true]
      end

      private

      # A lambda's own, or those of an object's #call.
      def parameters
        @command_runner.respond_to?(:parameters) ? @command_runner.parameters : @command_runner.method(:call).parameters
      end

      def run_injected(cmd, env, &)
        takes_env = parameters.count { |kind, _| %i[req opt].include?(kind) } > 1
        takes_env ? @command_runner.call(cmd, @environment.merge(env), &) : @command_runner.call(cmd, &)
      end
    end
  end
end
