# frozen_string_literal: true

module FunCi
  module Jobs
    # Where a project's jobs run and are recorded: the project's path, the
    # database, its Pipeline::Worktrees (#check_out), its job Locks, and
    # `clock`, which answers the time now.
    Site = Data.define(:project, :db, :worktrees, :locks, :clock)
  end
end
