# frozen_string_literal: true

module FunCi
  module Evidence
    # Where a failed stage's evidence can come from while it still holds its
    # slot (why.md, "Where evidence can come from"): the stage, the worktree
    # it ran in, its stage directory (`reports`), its environment as a hash,
    # the Stamp of each watched file when it started, by path, its budget,
    # its commit ({ sha:, branch: }) and when it started.
    Sources = Data.define(:stage, :worktree, :reports, :environment, :watched, :budget, :commit, :started)

    class Sources
      UNKNOWN = { watched: {}, budget: nil, commit: nil, started: nil }.freeze

      def initialize(**given) = super(**UNKNOWN, **given)
    end
  end
end
