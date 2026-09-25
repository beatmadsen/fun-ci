# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/pipeline/worktree_pool"

# AT-1.5: a run that dies holding its slot, without running any cleanup,
# doesn't keep the slot from the next pipeline.
class TestCrashedRunSlot < Minitest::Test
  Worktrees = Struct.new(:root) { def check_out(_path, _sha) = nil }

  def setup
    @root = Dir.mktmpdir("worktrees")
  end

  def teardown = FileUtils.rm_rf(@root)

  def test_the_next_pipeline_takes_the_slot_a_killed_run_held
    crash_holding_a_slot

    assert_equal File.join(@root, "slot-0"), pool.acquire("def5678").tap(&:release).path
  end

  private

  def pool = FunCi::Pipeline::WorktreePool.new(Worktrees.new(@root), size: 1, waiter: -> { flunk "waited" })

  # The child takes the slot, says so, and blocks on a pipe nobody writes to
  # until it is killed.
  def crash_holding_a_slot
    ready, told = IO.pipe
    pid = fork { hold_slot_until_killed(ready, told) }
    told.close
    ready.read(1)
    Process.kill("KILL", pid)
    assert_equal "KILL", Signal.signame(Process.wait2(pid).last.termsig)
  end

  def hold_slot_until_killed(ready, told)
    ready.close
    pool.acquire("abc1234")
    told.write("x")
    IO.pipe.first.read
  end
end
