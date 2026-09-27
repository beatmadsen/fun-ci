# frozen_string_literal: true

require_relative "stage_end"
require_relative "../evidence/start"

module FunCi
  module Pipeline
    # Runs a stage that has been started, in `dir`, with a report directory of
    # its own, and records how it ended while it still holds both. The same
    # for every stage, the slow suite in its forked child included.
    class StageExecution
      def initialize(seams:, dir:, commit:)
        @seams = seams
        @dir = dir
        @commit = commit
      end

      # Answers [the outcome recorded, what the stage printed].
      def run(stage, command, recorder, job_id)
        with_stage_dir do |stage_dir|
          collector = collector(stage, stage_dir)
          output, status, timed_out = execute(stage, command, stage_dir) { |pid| recorder.stage_process(job_id, pid) }
          finished = StageEnd::Finished.new(output: output, status: status, timed_out: timed_out)
          [StageEnd.new(recorder, job_id, collector).record(finished), output]
        end
      end

      private

      # The stage learns its name from FUN_CI_STAGE (acceptance-tests.md, AT-10.7).
      def execute(stage, command, stage_dir, &)
        window = stage_dir.window
        env = stage_dir.env.merge("FUN_CI_STAGE" => stage)
        @seams.executor(@dir).call(command, @seams.budgets[stage], env: env, output: window, &)
      ensure
        window&.close
      end

      def with_stage_dir
        stage_dir = @seams.stage_dir.call
        yield stage_dir
      ensure
        stage_dir&.remove
      end

      # Made before the stage runs, which is when its watched files are stamped.
      def collector(stage, stage_dir)
        environment = @seams.environment.merge(stage_dir.env)
        sources = Evidence::Sources.new(stage: stage, worktree: @dir, reports: stage_dir, environment: environment,
                                        budget: @seams.budgets[stage], commit: @commit.to_h, started: Time.now)
        commands = @seams.extractor_runner.call(dir: @dir, env: stage_dir.env, scratch: stage_dir.scratch)
        Evidence::Start.collector(sources, @seams.clock, commands)
      end
    end
  end
end
