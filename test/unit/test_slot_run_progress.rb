# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/slot_run_kit"

# What a git hook user sees as the run goes, and in what order. The wording
# of each line is ProgressReporter's.
class TestSlotRunProgress < Minitest::Test
  include SlotRunKit

  def test_should_report_phase_one_then_the_slow_suite_starting_then_the_fast_suite
    assert_equal ["fun-ci: lint ok  build ok  (phase 1 passed)", "fun-ci: slow (running in background)",
                  "fun-ci: fast ok"], progress_lines(scripted_runner)
  end

  def test_should_report_lint_before_build_whichever_finishes_first
    assert_equal "fun-ci: lint ok  build ok  (phase 1 passed)", progress_lines(build_finishing_first).first
  end

  def test_should_report_only_phase_one_when_it_fails
    assert_equal ["fun-ci: lint FAIL  build ok  (phase 1 failed)"],
                 progress_lines(scripted_runner({ "lint.sh" => ["", FakeStatus.new(false, 1)] }))
  end

  private

  def progress_lines(runner)
    io = quiet_io
    slot_run(slot_with(Lock.new(false)), io: io, command_runner: runner).run(config)
    io.stdout.string.lines(chomp: true).grep(/\Afun-ci: /)
  end
end
