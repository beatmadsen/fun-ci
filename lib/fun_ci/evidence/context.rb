# frozen_string_literal: true

module FunCi
  module Evidence
    # What an extractor is given about a failed stage (why.md, "Extractors"):
    # the stage, its output as the window kept it, the worktree it ran in
    # (read through #read, #exist?, #glob, #stamp and #lines_before, by path
    # relative to it), the deadline it checks as it goes, the Stamp of each
    # watched file when the stage started, by path, what is known About the
    # stage, `commands`, which runs a project's own extractors, and, for a
    # stage that ran over budget, before the kill, its process group (`pgid`)
    # and `processes`, which answers what ps lists.
    Context = Data.define(:stage, :output, :worktree, :deadline, :watched, :about, :commands, :pgid, :processes)

    class Context
      UNKNOWN = { watched: {}, about: nil, commands: nil, pgid: nil, processes: -> { [] } }.freeze

      def initialize(**given) = super(**UNKNOWN, **given)
    end
  end
end
