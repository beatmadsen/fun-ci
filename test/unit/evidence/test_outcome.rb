# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/outcome"

# How a failed stage ended; a stage over budget, or one `fun-ci extract` is
# told nothing about, has no exit status or signal to give.
class TestOutcome < Minitest::Test
  def test_should_know_no_exit_status_or_signal_it_was_not_given
    outcome = FunCi::Evidence::Outcome.new(state: "over_budget")

    assert_equal [nil, nil], [outcome.exit_status, outcome.signal]
  end

  def test_should_know_of_no_stage_alongside_or_overrun_it_was_not_given
    outcome = FunCi::Evidence::Outcome.new(state: "failed")

    assert_equal [[], nil], [outcome.alongside, outcome.overrun]
  end
end
