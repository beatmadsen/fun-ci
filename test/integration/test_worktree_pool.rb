# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/worktree_pool"

# The pool's locking, against real lock files and a stand-in for git.
class TestWorktreePool < Minitest::Test
  FakeWorktrees = Struct.new(:root, :checked_out) do
    def check_out(path, sha) = checked_out << [File.basename(path), sha]
  end

  def setup
    @base = Dir.mktmpdir("worktrees")
    @worktrees = FakeWorktrees.new(@base, [])
    @held = []
  end

  def teardown
    @held.each(&:release)
    FileUtils.rm_rf(@base)
  end

  def test_checks_out_the_commit_in_the_first_free_slot
    hold(pool.acquire("abc1234"))

    assert_equal [%w[slot-0 abc1234]], @worktrees.checked_out
  end

  def test_a_second_pipeline_gets_a_slot_of_its_own
    hold(pool.acquire("abc1234"))

    assert_equal File.join(@worktrees.root, "slot-1"), hold(pool.acquire("def5678")).path
  end

  def test_waits_while_every_slot_is_taken
    first = pool(size: 1).acquire("abc1234")
    waits = []
    hold(pool(size: 1, waiter: -> { waits << first.release }).acquire("def5678"))

    assert_equal 1, waits.size
  end

  def test_takes_the_slot_that_frees_while_it_waits
    first = pool(size: 1).acquire("abc1234")

    second = pool(size: 1, waiter: -> { first.release }).acquire("def5678")

    assert_equal File.join(@worktrees.root, "slot-0"), hold(second).path
  end

  def test_takes_a_slot_whose_lock_names_a_process_that_is_gone
    File.write(File.join(@worktrees.root, "slot-0.lock"), "999999")

    assert_equal File.join(@worktrees.root, "slot-0"), hold(pool(size: 1).acquire("abc1234")).path
  end

  def test_creates_the_worktrees_directory_the_first_time
    @worktrees.root = File.join(@worktrees.root, "not", "there", "yet")

    assert_equal File.join(@worktrees.root, "slot-0"), hold(pool.acquire("abc1234")).path
  end

  def test_names_the_lock_file_of_the_slot_it_hands_out
    assert_equal File.join(@worktrees.root, "slot-0.lock"), hold(pool.acquire("abc1234")).lock_file
  end

  def test_writes_its_own_pid_over_a_longer_one_left_in_the_lock
    File.write(File.join(@worktrees.root, "slot-0.lock"), "1234567890123")
    hold(pool.acquire("abc1234"))

    assert_equal Process.pid.to_s, File.read(File.join(@worktrees.root, "slot-0.lock"))
  end

  # GC stays off so a leaked File can't be closed behind the count's back.
  def test_keeps_no_descriptor_open_on_a_slot_it_found_taken
    hold(pool.acquire("abc1234"))
    GC.disable
    before = Dir.children("/dev/fd").size
    hold(pool.acquire("def5678"))

    assert_equal before + 1, Dir.children("/dev/fd").size
  ensure
    GC.enable
  end

  private

  def pool(size: 2, waiter: -> { flunk "waited with a slot free" })
    FunCi::Pipeline::WorktreePool.new(@worktrees, size: size, waiter: waiter)
  end

  def hold(slot)
    @held << slot
    slot
  end
end
