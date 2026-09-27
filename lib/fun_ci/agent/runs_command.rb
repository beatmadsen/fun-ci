# frozen_string_literal: true

require "time"
require_relative "command_support"
require_relative "output"
require_relative "age"

module FunCi
  module Agent
    # `fun-ci runs [-n N] [--branch NAME] [--json]` (acceptance-tests.md, AT-9.4).
    class RunsCommand
      include CommandSupport

      NAME = "runs"

      def initialize(context)
        @context = context
      end

      def run(args)
        options = Options.parse(args, takes: %i[limit branch json])
        entries = reports.recent(limit: options.limit, branch: options.branch).map { |run, report| [report, age(run)] }
        Output.new(@context.io.stdout, json: options.json).runs(entries)
        0
      rescue Options::Invalid => e
        usage(e.message)
      end

      private

      def age(run) = Age.words(@context.clock.now - Time.parse(run[:created_at]))
    end
  end
end
