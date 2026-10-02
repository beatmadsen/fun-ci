# frozen_string_literal: true

require_relative "wall_clock_wait"

module FunCi
  module Jobs
    # Where a project's jobs run and are recorded: the project's path, the
    # database, its Pipeline::Worktrees (#check_out), its job Locks,
    # `clock`, which answers the time now, and `wait`, which waits the
    # seconds it is given, for a run's turn to start (Schedule).
    Site = Data.define(:project, :db, :worktrees, :locks, :clock, :wait)

    class Site
      def initialize(wait: WallClockWait.new, **given) = super
    end
  end
end
