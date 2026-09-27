# frozen_string_literal: true

require_relative "context"
require_relative "deadline"
require_relative "worktree"
require_relative "about_stage"

module FunCi
  module Evidence
    # Makes the Context a stage's extractors are given, with a deadline
    # `seconds` from now.
    class StageContext
      def initialize(sources, clock, commands)
        @sources = sources
        @clock = clock
        @commands = commands
      end

      def after(output, outcome, seconds)
        Context.new(stage: @sources.stage, output: output, worktree: Worktree.new(@sources.worktree),
                    deadline: Deadline.after(@clock, seconds), watched: @sources.watched,
                    about: AboutStage.of(@sources, outcome, output), commands: @commands,
                    processes: @sources.processes)
      end

      # Before the kill of a stage over budget, while its group still runs.
      def before_kill(pgid, seconds) = after("", Outcome.new(state: "over_budget"), seconds).with(pgid: pgid)
    end
  end
end
