# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../script/suites_apart"

# What the weekly check makes of one stack's run in its image
# (script/suites_apart.rb): the stages that run at once write nothing in
# common, and the run shows the suites ran tests, or it proves nothing.
class TestSuitesApart < Minitest::Test
  CLEAN = <<~OUT
    lint exit 0 wrote 2
    build exit 0 wrote 9
    == lint/build
    together fast exit 1
    together slow exit 0
    fast exit 1 wrote 3
    slow exit 0 wrote 2
    == fast/slow
    == together fast output
    FAILED CartTest > startsEmpty
    == together slow output
    Tests run: 1, Failures: 0
  OUT

  def test_should_pass_a_run_where_the_stages_kept_apart_and_both_suites_ran_tests
    assert_empty verdict("maven", CLEAN).problems
  end

  def test_should_fail_a_run_with_no_measurement_of_a_stage
    assert_includes verdict("maven", CLEAN.sub("build exit 0 wrote 9\n", "")).problems,
                    "build has no measurement"
  end

  def test_should_fail_a_run_whose_build_failed
    assert_includes verdict("maven", CLEAN.sub("build exit 0", "build exit 1")).problems, "build.sh exited 1"
  end

  def test_should_fail_a_path_lint_and_build_both_wrote
    assert_includes verdict("maven", CLEAN.sub("== lint/build\n", "== lint/build\n./target/classes/Cart.class\n"))
      .problems, "lint and build both write ./target/classes/Cart.class"
  end

  def test_should_fail_a_path_both_suites_wrote
    assert_includes verdict("maven", CLEAN.sub("== fast/slow\n", "== fast/slow\n./target/test-classes/A.class\n"))
      .problems, "fast and slow both write ./target/test-classes/A.class"
  end

  def test_should_let_both_suites_write_what_their_tool_shares_safely
    assert_empty verdict("gradle", gradle(CLEAN.sub("== fast/slow\n", "== fast/slow\n./.gradle/8.14/fileHashes.bin\n")))
      .problems
  end

  def test_should_not_let_a_path_beside_what_the_tool_shares_through
    assert_includes verdict("gradle", gradle(CLEAN.sub("== fast/slow\n", "== fast/slow\n./build/classes/A.class\n")))
      .problems, "fast and slow both write ./build/classes/A.class"
  end

  def test_should_fail_a_run_whose_fast_suite_ran_no_tests_beside_the_slow_suite
    assert_includes verdict("maven", CLEAN, fast_ran: false).problems, "fast ran no tests beside slow"
  end

  def test_should_fail_a_run_whose_slow_suite_ran_no_tests_beside_the_fast_suite
    assert_includes verdict("maven", CLEAN.sub("Tests run: 1", "Tests run: 0")).problems,
                    "slow ran no tests beside fast"
  end

  def test_should_say_so_when_the_stack_s_recording_has_no_slow_test
    assert_equal ["slow not measured: its recording has no slow test"], verdict("jest", CLEAN).notes
  end

  def test_should_say_so_when_lint_failed_before_it_could_write_what_it_writes
    assert_equal ["lint exited 127, so what it writes may not be measured"],
                 verdict("maven", CLEAN.sub("lint exit 0", "lint exit 127")).notes
  end

  private

  def verdict(stack, output, fast_ran: true) = SuitesApart.verdict(stack, output, fast_ran: ->(_) { fast_ran })

  def gradle(output) = output.sub("Tests run: 1, Failures: 0", "There were failing tests.")
end
