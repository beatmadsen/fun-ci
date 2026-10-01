# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/slot_run_kit"

# A slot whose worktree was just made has no caches, so a run there gives
# lint and build the slow suite's budget once, and says why (AT-1.14): a
# cold build is fun-ci's doing, no measure of the project's.
class TestSlotRunCold < Minitest::Test
  include SlotRunKit

  def test_should_give_the_build_the_slow_suite_s_budget_in_a_cold_slot
    assert_equal 300, budgets_in(cold_slot)["build"]
  end

  def test_should_give_lint_the_slow_suite_s_budget_in_a_cold_slot
    assert_equal 300, budgets_in(cold_slot)["lint"]
  end

  def test_should_keep_the_fast_suite_s_budget_in_a_cold_slot
    assert_equal 10, budgets_in(cold_slot)["fast"]
  end

  def test_should_keep_the_build_s_budget_in_a_warm_slot
    assert_equal 30, budgets_in(slot_with(Lock.new(false)))["build"]
  end

  def test_should_say_why_lint_and_build_have_longer_this_once
    io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: StringIO.new)
    slot_run(cold_slot, io: io).run(config)

    assert_includes io.stdout.string,
                    "fun-ci: a new worktree, whose caches are empty, so lint and build have 300s this once.\n"
  end

  private

  def cold_slot = FunCi::Pipeline::ColdSlot.new("/slot-0", Lock.new(false))

  def budgets_in(slot)
    recorder = FakeRecorder.new
    slot_run(slot, recorder: recorder).run(config)
    recorder.budgets
  end
end
