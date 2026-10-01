# frozen_string_literal: true

require_relative "stage_end"
require_relative "../evidence/start"

module FunCi
  module Pipeline
    # Runs a stage that has been started, in `dir`, with a stage directory of
    # its own, and records how it ended while it still holds both. The same
    # for every stage, the slow suite in its forked child included, and for
    # a daily or weekly job.
    class StageExecution
      # launching: what the script is launched with besides its output window
      # (ProcessRunner::Launch): what it is told about itself, by default its
      # stage's name in FUN_CI_STAGE (acceptance-tests.md, AT-10.7), and the
      # files it holds open.
      def initialize(seams:, dir:, commit:, launching: {})
        @seams = seams
        @dir = dir
        @commit = commit
        @launching = launching
      end

      # Answers [the outcome recorded, what the stage printed].
      def run(stage, command, recorder, job_id)
        with_stage_dir do |stage_dir|
          collector = collector(stage, stage_dir)
          finished = finished(stage, command, stage_dir, collector) { |pid| recorder.stage_process(job_id, pid) }
          [StageEnd.new(recorder, job_id, collector).record(finished), finished.output]
        end
      end

      private

      # A stage over budget is looked at before the kill (acceptance-tests.md, AT-10.17).
      def finished(stage, command, stage_dir, collector, &)
        overrun = nil
        output, status, timed_out = execute(stage, command, stage_dir, lambda { |pgid|
          overrun = collector.before_kill(pgid)
        },
                                            &)
        StageEnd::Finished.new(output: output, status: status, timed_out: timed_out, overrun: overrun)
      end

      def execute(stage, command, stage_dir, before_kill, &)
        window = stage_dir.window
        launch = ProcessRunner::Launch.new(env: { "FUN_CI_STAGE" => stage }, **@launching, output: window,
                                           before_kill: before_kill)
        @seams.executor(@dir).call(command, @seams.budgets[stage], launch, &)
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
        sources = Evidence::Sources.new(stage: stage, worktree: @dir, stage_dir: stage_dir,
                                        environment: @seams.environment,
                                        budget: @seams.budgets[stage], commit: @commit.to_h, started: Time.now,
                                        processes: @seams.process_table)
        commands = @seams.extractor_runner.call(dir: @dir, scratch: stage_dir.scratch)
        Evidence::Start.collector(sources, @seams.clock, commands)
      end
    end
  end
end
