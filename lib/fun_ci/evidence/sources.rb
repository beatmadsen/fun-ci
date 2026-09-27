# frozen_string_literal: true

module FunCi
  module Evidence
    # Where a failed stage's evidence can come from while it still holds its
    # slot (why.md, "Where evidence can come from"): the stage, the worktree
    # it ran in, its report directory, its environment as a hash, and the
    # Stamp of each watched file when it started, by path.
    Sources = Data.define(:stage, :worktree, :reports, :environment, :watched)

    class Sources
      def initialize(watched: {}, **) = super
    end
  end
end
