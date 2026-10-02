# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/starts_in"

# When a job waiting its turn starts, as agents are told it (AT-13.28).
class TestStartsIn < Minitest::Test
  def test_should_say_when_a_waiting_job_starts
    assert_equal "starts in 6h", FunCi::Agent::StartsIn.words(21_600)
  end

  def test_should_say_a_job_starts_now_at_the_moment_of_its_turn
    assert_equal "starts now", FunCi::Agent::StartsIn.words(0)
  end

  def test_should_say_a_job_starts_now_once_its_turn_has_passed
    assert_equal "starts now", FunCi::Agent::StartsIn.words(-30)
  end
end
