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

  def test_should_list_reported_failures_instead_of_the_kept_lines
    failures = [{ file: "t.rb", line: 41, test: "T#test_a", message: "Expected 3\ngot 1" }]

    assert_equal ["fast failed:", "  t.rb:41  T#test_a", "    Expected 3", "    got 1"],
                 evidence(fast: ["failed", TAIL, failures])
  end

  def test_should_show_the_first_5_lines_of_a_failure_s_message
    failures = [{ file: "t.rb", line: 1, test: "t", message: (1..8).map { |n| "m#{n}" }.join("\n") }]

    assert_equal %w[m1 m2 m3 m4 m5], evidence(fast: ["failed", nil, failures]).drop(2).map(&:strip)
  end

  def test_should_list_at_most_10_failures
    failures = (1..12).map { |n| { file: "t.rb", line: n, test: "t#{n}", message: "m" } }

    assert_equal(10, evidence(fast: ["failed", nil, failures]).count { |line| line.start_with?("  t.rb:") })
  end

  def test_should_name_a_failure_without_a_file_by_its_test
    assert_equal "  lint: bad",
                 evidence(fast: ["failed", nil, [{ file: nil, line: nil, test: "lint: bad", message: "" }]])[1]
  end

  def test_should_end_with_the_why_command_for_the_stage_that_decided
    assert_equal "fun-ci why 3f9c2ab fast", evidence(deciding: "fast", fast: %W[failed boom\n]).last
  end

  private

  def evidence(deciding: nil, **given)
    stages = %w[lint build fast slow].map do |name|
      state, tail, failures = given.fetch(name.to_sym, ["passed", nil])
      STAGE.new(name: name, state: state, seconds: 1.0, kept: REPORT::Kept.new(tail: tail, failures: failures || []))
    end
    FunCi::Agent::StatusText.lines(report(stages, deciding)).drop(5)
  end

  def report(stages, deciding)
    REPORT.new(sha: "3f9c2ab0c4d1", subject: "Add retry", branch: "main", need: "fast", stages: stages,
               verdict: :failed, deciding: deciding, superseded_by: nil)
  end
end
