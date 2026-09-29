# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/exit_code"

# The exit codes agents branch on are a published contract
# (acceptance-tests.md, §9): a change here breaks every agent that reads them.
class TestExitCode < Minitest::Test
  def test_should_give_each_verdict_its_published_exit_code
    assert_equal({ passed: 0, failed: 1, over_budget: 2, undecided: 3, superseded: 4, unknown: 5, conflicts: 6 },
                 FunCi::Agent::ExitCode::FOR)
  end

  def test_should_exit_64_on_a_usage_error
    assert_equal 64, FunCi::Agent::ExitCode::USAGE
  end
end
