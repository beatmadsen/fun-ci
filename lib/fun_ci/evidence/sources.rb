# frozen_string_literal: true

module FunCi
  module Evidence
    # Where a failed stage's evidence can come from while it still holds its
    # slot (architecture.md, "Evidence of a failed stage"): the stage, the worktree
    # it ran in, its stage directory (`reports`), its environment as a hash,
    # the Stamp of each watched file when it started, by path, its budget,
    # its commit ({ sha:, branch: }), when it started, `processes`, which
    # answers what ps lists, for a stage that runs over budget, and the
    # presets that were candidates when it started (Detection::Found).
    Sources = Data.define(:stage, :worktree, :reports, :environment, :watched, :budget, :commit, :started, :processes,
                          :candidates)

    class Sources
      UNKNOWN = { watched: {}, budget: nil, commit: nil, started: nil, processes: -> { [] }, candidates: [] }.freeze

      def initialize(**given) = super(**UNKNOWN, **given)
    end
  end
end
