# frozen_string_literal: true

module FunCi
  module Pipeline
    # Each stage's time budget in seconds (design.md); a worktree just made
    # gives lint and build the slow suite's, once (SlotRun).
    DEFAULT_BUDGETS = { "lint" => 30, "build" => 30, "fast" => 10, "slow" => 300 }.freeze
  end
end
