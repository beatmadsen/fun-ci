# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/stage_summary"
require "fun_ci/agent/report_stage"

# How a stage or a job's run ended, against its budget (acceptance-tests.md, AT-10.1, AT-13.21).
class TestStageSummary < Minitest::Test
  def test_should_say_a_budget_of_whole_hours_in_hours
    assert_equal "soak failed after 2.0s, budget 1h", line(3600)
  end

  def test_should_say_a_budget_of_hours_and_a_part_in_seconds
    assert_equal "soak failed after 2.0s, budget 5400s", line(5400)
  end

  def test_should_say_a_budget_under_an_hour_in_seconds
    assert_equal "soak failed after 2.0s, budget 300s", line(300)
  end

  private

  def line(budget)
    ended = FunCi::Agent::RunReport::Exit.new(exit_status: nil, signal: nil, budget: budget)
    stage = FunCi::Agent::RunReport::Stage.new(name: "soak", state: "failed", seconds: 2.0, exit: ended)
    FunCi::Agent::StageSummary.line(stage)
  end
end
