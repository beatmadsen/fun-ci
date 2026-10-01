# frozen_string_literal: true

require_relative "command_support"
require_relative "output"
require_relative "trunk_why"
require_relative "job_why"

module FunCi
  module Agent
    # `fun-ci why [REV] [STAGE] [--need LEVEL] [--json] [--raw]`
    # (acceptance-tests.md, AT-10.1, AT-10.6): everything kept about the stage
    # named, or else about the stage that decided the verdict; with --raw, the
    # raw output it kept, and nothing else. With `--job NAME`, the same about
    # a daily or weekly job's latest run (JobWhy).
    class WhyCommand
      include CommandSupport

      NAME = "why"

      def initialize(context)
        @context = context
      end

      def run(args)
        options = Options.parse(args, takes: %i[need json stage raw job])
        return JobWhy.new(@context, job_reports).answer(options) if options.job

        sha = resolve(options.rev)
        answer(sha, reports.for(sha, options.need), options)
      rescue Options::Invalid => e
        usage(e.message)
      end

      private

      def answer(sha, report, options)
        output = Output.new(@context.io.stdout, json: options.json)
        return output.unknown(sha) unless report

        stage_name = options.stage || report.deciding
        return why_trunk(report, output) if stage_name == "trunk"

        options.raw ? raw(report, stage_name) : output.why(report, stage_name)
        ExitCode::FOR.fetch(report.verdict)
      end

      # The conflict merged again; nothing to explain unless the run's commit conflicts.
      def why_trunk(report, output)
        trunk = report.trunk
        tip = trunk&.state == "conflicts" ? trunk.check.tip : nil
        output.why_trunk(report, tip && TrunkWhy.document(@context.trunk.explain(report.sha, tip), tip))
        ExitCode::FOR.fetch(report.verdict)
      end

      def raw(report, stage_name)
        stage = report.stages.find { |candidate| candidate.name == stage_name }
        text = stage && reports.raw_output(stage)
        return @context.io.stdout.write(text) if text

        @context.io.stderr.puts "fun-ci why: no raw output is kept for #{stage_name || "any stage"} of #{report.sha[0,
                                                                                                                    7]}"
      end
    end
  end
end
