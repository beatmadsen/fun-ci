# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/worktree_pool"

# A slot held only by a slow suite waiting its branch's turn keeps its
# checkout, but takes no place in the pool: another branch's run gets a
# further slot meanwhile (acceptance-tests.md, AT-9.19).
class TestWorktreePoolWaiting < Minitest::Test
  # Every checkout succeeds, in a worktree made before.
  FakeWorktrees = Struct.new(:root) do
    def check_out(*, **) = nil
  end

  def setup
    @base = Dir.mktmpdir("worktrees")
    @slots = []
    @marks = []
  end

  def teardown
    @marks.each(&:close)
    @slots.each(&:release)
    FileUtils.rm_rf(@base)
  end

  def test_should_hand_out_a_further_slot_while_the_taken_one_waits_for_its_slow_suite_s_turn
    @marks << hold(pool.acquire("abc1234")).waiting

    assert_equal File.join(@base, "slot-1"), hold(pool.acquire("def5678")).path
  end

  def test_should_wait_for_a_slot_once_the_waiting_slow_suite_s_turn_has_come
    hold(pool.acquire("abc1234")).waiting.close

    assert_raises(NoSlot) { pool(waiter: -> { raise NoSlot }).acquire("def5678") }
  end

  def test_should_count_no_slot_waiting_whose_slow_suite_s_process_is_gone
    File.write(File.join(FileUtils.mkdir_p(File.join(@base, "waiting")).first, "slot-0.lock"), "")
    hold(pool.acquire("abc1234"))

    assert_raises(NoSlot) { pool(waiter: -> { raise NoSlot }).acquire("def5678") }
  end

  private

  class NoSlot < StandardError; end

  def pool(waiter: -> { flunk "waited with a slot free" })
    FunCi::Pipeline::WorktreePool.new(FakeWorktrees.new(@base), size: 1, waiter: waiter)
  end

  def hold(slot)
    @slots << slot
    slot
  end
end
