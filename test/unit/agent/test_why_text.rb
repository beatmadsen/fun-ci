# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/why_text"

# What `fun-ci why` prints about one stage (acceptance-tests.md, AT-10.1).
class TestWhyText < Minitest::Test
  REPORT = FunCi::Agent::RunReport
  EXIT = REPORT::Exit
  FAILURE = { file: "t.rb", line: 41, test: "T#test_a", message: "Expected 3\ngot 1", extractor: "test-reports" }.freeze

  def test_should_start_with_the_commit
    assert_equal %(fun-ci: 3f9c2ab "Add retry" on main), lines(stage("failed")).first
  end

  def test_should_say_how_the_stage_exited_how_long_it_took_and_its_budget
    assert_equal "fast failed (exit 1) after 8.4s, budget 10s",
                 lines(stage("failed", seconds: 8.4, exit: EXIT.new(exit_status: 1, signal: nil, budget: 10)))[1]
  end

  def test_should_name_the_signal_that_ended_the_stage
    assert_equal "fast failed (killed by SIGSEGV)",
                 lines(stage("failed", exit: EXIT.new(exit_status: nil, signal: "SEGV", budget: nil)))[1]
  end

  def test_should_say_a_stage_ran_over_budget
    assert_equal "fast ran over budget", lines(stage("over_budget"))[1]
  end

  def test_should_print_each_failure_with_its_whole_message_under_the_extractor_that_found_it
    assert_equal ["", "Failures, from test-reports:", "  t.rb:41  T#test_a", "    Expected 3", "    got 1"],
                 lines(stage("failed", kept: { failures: [FAILURE] })).drop(2)
  end

  def test_should_print_the_kept_tail_under_its_title
    assert_equal ["", "The output's last lines, from output-tail:", "  one", "  two"],
                 lines(stage("failed", kept: { tail: "one\ntwo\n" })).drop(2)
  end

  def test_should_say_the_evidence_of_a_failed_stage_was_pruned
    assert_equal ["Its evidence is no longer kept: fun-ci keeps it for a project's 50 newest runs."],
                 lines(stage("failed", kept: { pruned: true })).drop(2)
  end

  def test_should_end_with_the_command_that_prints_the_raw_output_when_it_is_kept
    assert_equal "The whole output: fun-ci why 3f9c2ab fast --raw",
                 lines(stage("failed", kept: { raw_bytes: 1843 })).last
  end

  def test_should_say_nothing_is_kept_for_a_stage_that_passed
    assert_equal ["fast passed", "Nothing is kept about a stage that passed."], lines(stage("passed")).drop(1)
  end

  private

  def stage(state, seconds: nil, exit: REPORT::NO_EXIT, kept: {})
    REPORT::Stage.new(name: "fast", state: state, seconds: seconds, exit: exit,
                      kept: REPORT::Kept.new(tail: nil, failures: [], **kept))
  end

  def lines(stage)
    report = REPORT.new(sha: "3f9c2ab0c4d1", subject: "Add retry", branch: "main", need: "fast", stages: [stage],
                        verdict: :failed, deciding: "fast", superseded_by: nil)
    FunCi::Agent::WhyText.lines(report, stage)
  end
end
