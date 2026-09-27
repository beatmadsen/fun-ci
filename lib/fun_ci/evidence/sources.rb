# frozen_string_literal: true

module FunCi
  module Evidence
    # Where a failed stage's evidence can come from while it still holds its
    # slot (why.md, "Where evidence can come from"): the stage, the worktree
    # it ran in, its report directory, and its environment as a hash.
    Sources = Data.define(:stage, :worktree, :reports, :environment)
  end
end
