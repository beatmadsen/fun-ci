# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/slow_turns"
require "fun_ci/pipeline/slot_lock"

# A branch's slow suites take turns through a lock file of the branch's
# (acceptance-tests.md, AT-9.19).
class TestSlowTurns < Minitest::Test
  def setup
    @turns = FunCi::Pipeline::SlowTurns.new(File.join(Dir.mktmpdir, "slow"))
  end

  def test_should_hold_the_branch_s_turn_while_its_slow_suite_runs
    held = @turns.take("main") { held?("main") }

    assert held
  end

  def test_should_let_the_turn_go_once_its_slow_suite_is_done
    @turns.take("main") { nil }

    refute held?("main")
  end

  def test_should_leave_another_branch_s_turn_free
    free = @turns.take("main") { held?("feature/x") }

    refute free
  end

  private

  def held?(branch) = FunCi::Pipeline::SlotLock.held?(@turns.lock_path(branch))
end
