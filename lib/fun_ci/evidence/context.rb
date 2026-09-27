# frozen_string_literal: true

module FunCi
  module Evidence
    # What an extractor is given about a failed stage (why.md, "Extractors"):
    # the stage, its output as the window kept it, the worktree it ran in
    # (read through #read, #exist?, #glob, #stamp and #lines_before, by path
    # relative to it), the deadline it checks as it goes, the Stamp of each
    # watched file when the stage started, by path, what is known About the
    # stage, and `commands`, which runs a project's own extractors.
    Context = Data.define(:stage, :output, :worktree, :deadline, :watched, :about, :commands)

    class Context
      def initialize(watched: {}, about: nil, commands: nil, **) = super
    end
  end
end
