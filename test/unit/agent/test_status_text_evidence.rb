# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/status_text"

# After the stage lines, the evidence of each needed stage that failed (AT-9.6).
class TestStatusTextEvidence < Minitest::Test
  REPORT = FunCi::Agent::RunReport
  STAGE = REPORT::Stage
  TAIL = (1..30).map { |n| "line #{n}\n" }.join

  def test_should_follow_the_stages_with_the_last_20_kept_lines_of_a_failed_stage
    assert_equal ["fast failed:", *(11..30).map { |n| "  line #{n}" }], evidence(fast: ["failed", TAIL])
  end

  def test_should_say_a_stage_ran_over_budget
    assert_equal ["fast ran over budget:", "  last words"], evidence(fast: ["over_budget", "last words\n"])
  end

  def test_should_name_a_failed_stage_that_kept_no_output
    assert_equal ["fast failed:"], evidence(fast: ["failed", nil])
  end

  def test_should_show_each_needed_stage_that_failed_in_pipeline_order
    assert_equal ["lint failed:", "  lint says", "build failed:", "  build says"],
                 evidence(lint: ["failed", "lint says\n"], build: ["failed", "build says\n"])
  end

  def test_should_leave_out_a_stage_the_level_does_not_need
    assert_empty evidence(slow: ["failed", "slow says\n"])
  end

  private

  def evidence(**given)
    stages = %w[lint build fast slow].map do |name|
      state, tail = given.fetch(name.to_sym, ["passed", nil])
      STAGE.new(name: name, state: state, seconds: 1.0, tail: tail)
    end
    FunCi::Agent::StatusText.lines(report(stages)).drop(5)
  end

  def report(stages)
    REPORT.new(sha: "3f9c2ab0c4d1", subject: "Add retry", branch: "main", need: "fast", stages: stages,
               verdict: :failed, superseded_by: nil)
  end
end
