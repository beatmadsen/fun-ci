# frozen_string_literal: true

module FunCi
  module Evidence
    # What is known about a failed stage when its evidence is collected, as a
    # project's command is told it: how it ended, its budget, the stages
    # alongside it, the commit, where it ran, when it started, and where its
    # output and reports are.
    About = Data.define(:stage, :state, :exit_status, :signal, :seconds, :budget, :alongside, :commit, :worktree,
                        :started_at, :output, :reports)
  end
end
