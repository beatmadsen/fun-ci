# frozen_string_literal: true

module FunCi
  module Evidence
    # What an extractor is given about a failed stage (why.md, "Extractors"):
    # the stage, its output as the window kept it, the worktree it ran in
    # (read through #read, #exist? and #glob, by path relative to it), and the
    # deadline it checks as it goes.
    Context = Data.define(:stage, :output, :worktree, :deadline)
  end
end
