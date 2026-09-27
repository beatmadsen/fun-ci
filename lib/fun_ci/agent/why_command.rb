# frozen_string_literal: true

require_relative "command_support"
require_relative "output"

module FunCi
  module Agent
    # `fun-ci why [REV] [STAGE] [--need LEVEL] [--json]` (acceptance-tests.md,
    # AT-10.1): everything kept about the stage named, or else about the stage
    # that decided the verdict.
    class WhyCommand
      include CommandSupport

      NAME = "why"

      def initialize(context)
        @context = context
      end

      def run(args)
        options = Options.parse(args, takes: %i[need json stage])
        sha = resolve(options.rev)
        answer(sha, reports.for(sha, options.need), options)
      rescue Options::Invalid => e
        usage(e.message)
      end

      private

      def answer(sha, report, options)
        output = Output.new(@context.io.stdout, json: options.json)
        return output.unknown(sha) unless report

        output.why(report, options.stage || report.deciding)
        ExitCode::FOR.fetch(report.verdict)
      end
    end
  end
end
