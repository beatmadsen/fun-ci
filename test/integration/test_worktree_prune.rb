# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/worktree_pool"
require "fun_ci/pipeline/worktree_prune"

# AT-1.11: pruning removes the pool's worktrees, against real lock files and a
# stand-in for git.
class TestWorktreePrune < Minitest::Test
  FakeWorktrees = Struct.new(:root, :pruned) do
    def check_out(path, _sha) = FileUtils.mkdir_p(path)
    def prune = pruned << :pruned
  end

  def setup
    @base = Dir.mktmpdir("worktrees")
    @worktrees = FakeWorktrees.new(File.join(@base, "fun-ci", "worktrees"), [])
  end

  def teardown = FileUtils.rm_rf(@base)

  def test_should_remove_every_slot_when_no_run_holds_one
    check_out_slots(2)
    prune

    assert_empty Dir.glob(File.join(@worktrees.root, "slot-?"))
  end

  def test_should_have_git_forget_the_removed_worktrees
    check_out_slots(1)
    prune

    assert_equal [:pruned], @worktrees.pruned
  end

  def test_should_answer_how_many_slots_it_removed
    check_out_slots(2)

    assert_equal 2, prune
  end

  def test_should_remove_nothing_when_no_pipeline_ever_ran
    assert_equal 0, prune
  end

  def test_should_refuse_while_a_run_holds_a_slot
    held = pool(2).acquire("abc1234")

    assert_raises(FunCi::Pipeline::WorktreePrune::Busy) { prune }
  ensure
    held.release
  end

  def test_should_leave_every_slot_in_place_while_a_run_holds_one
    check_out_slots(2)
    held = pool(1).acquire("abc1234")
    assert_raises(FunCi::Pipeline::WorktreePrune::Busy) { prune }

    assert_equal 2, Dir.glob(File.join(@worktrees.root, "slot-?")).size
  ensure
    held.release
  end

  def test_should_let_go_of_the_free_slots_when_it_refuses
    first, second = Array.new(2) { pool(2).acquire("abc1234") }
    first.release
    assert_raises(FunCi::Pipeline::WorktreePrune::Busy) { prune }

    free = pool(1, waiter: -> { flunk "slot-0 is still locked" }).acquire("abc1234").tap(&:release)

    assert_equal File.join(@worktrees.root, "slot-0"), free.path
  ensure
    second.release
  end

  def test_should_let_the_next_run_take_a_slot_after_pruning
    check_out_slots(1)
    prune
    slot = pool(1).acquire("abc1234")

    assert Dir.exist?(slot.path)
  ensure
    slot&.release
  end

  private

  def pool(size, waiter: -> {}) = FunCi::Pipeline::WorktreePool.new(@worktrees, size: size, waiter: waiter)
  def prune = FunCi::Pipeline::WorktreePrune.new(@worktrees).run

  def check_out_slots(count)
    slots = Array.new(count) { pool(count).acquire("abc1234") }
    slots.each(&:release)
  end
end
