# frozen_string_literal: true

module FunCi
  module Agent
    # What `status` and `wait` exit with (acceptance-tests.md, §9).
    module ExitCode
      FOR = { passed: 0, failed: 1, over_budget: 2, undecided: 3, superseded: 4, unknown: 5 }.freeze
      USAGE = 64
    end
  end
end
