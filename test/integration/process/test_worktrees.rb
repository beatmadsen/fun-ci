# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require "fun_ci/pipeline/worktrees"
require "fun_ci/persistence/state_dir"

# The git a worktree slot needs, against a real repository (AT-1.1 to 1.3):
# a slot is a checkout of the commit asked for, not of HEAD or of the
# working tree, and a slot reused for a later commit keeps ignored caches
# but not untracked files. The pool hands out the path (test_worktree_pool),
# and SlotRun runs the stages there (test_slot_run_processes).
class TestWorktrees < Minitest::Test
  def setup
    @project = GitProject.create
    @project.write(".gitignore", "vendor/cache/\n")
    @first, @second = %w[first second].map { |value| commit_value(value) }
    @worktrees = FunCi::Pipeline::Worktrees.new(@project.dir)
  end

  def teardown = @project.remove

  # Tools that treat .git/ as private, such as Vite's default fs.deny, refuse a checkout under it.
  def test_should_keep_slots_outside_the_repository_s_git_directory
    refute_includes @worktrees.root.split(File::SEPARATOR), ".git"
  end

  def test_should_keep_slots_in_fun_ci_s_state_directory
    assert @worktrees.root.start_with?(FunCi::Persistence::StateDir.path(ENV))
  end

  def test_should_keep_the_jobs_worktrees_beside_the_slots
    assert_equal File.dirname(@worktrees.root), File.dirname(@worktrees.jobs_root)
  end

  def test_should_give_every_git_worktree_of_a_repository_the_same_slots
    other = File.join(Dir.mktmpdir("other"), "checkout")
    @project.git("worktree", "add", "--detach", other, @first)

    assert_equal @worktrees.root, FunCi::Pipeline::Worktrees.new(other).root
  ensure
    FileUtils.rm_rf(File.dirname(other))
  end

  def test_should_give_another_repository_slots_of_its_own
    twin = GitProject.create

    refute_equal @worktrees.root, FunCi::Pipeline::Worktrees.new(twin.dir).root
  ensure
    twin&.remove
  end

  def test_should_say_it_made_the_slot_s_worktree_the_first_time
    assert @worktrees.check_out(slot, @first)
  end

  def test_should_say_it_made_nothing_when_it_reuses_a_slot
    @worktrees.check_out(slot, @first)

    refute @worktrees.check_out(slot, @second)
  end

  def test_should_check_out_the_commit_asked_for_not_head
    @worktrees.check_out(slot, @first)

    assert_equal "first\n", File.read(File.join(slot, "value.txt"))
  end

  def test_should_check_out_committed_content_not_the_working_tree_s_edits
    @project.write("value.txt", "edited, not committed\n")
    @worktrees.check_out(slot, @second)

    assert_equal "second\n", File.read(File.join(slot, "value.txt"))
  end

  def test_should_move_a_reused_slot_to_the_next_commit
    reuse_slot

    assert_equal "second\n", File.read(File.join(slot, "value.txt"))
  end

  def test_should_keep_ignored_files_in_a_reused_slot
    reuse_slot

    assert File.exist?(File.join(slot, "vendor", "cache", "marker"))
  end

  def test_should_remove_untracked_files_from_a_reused_slot
    reuse_slot

    refute File.exist?(File.join(slot, "scratch.txt"))
  end

  def test_should_raise_what_git_said_when_a_checkout_fails
    error = assert_raises(FunCi::Pipeline::Worktrees::GitError) { @worktrees.check_out(slot, "0" * 40) }

    assert_match(/git worktree add .*: fatal/, error.message)
  end

  private

  def slot = File.join(@worktrees.root, "slot-0")

  def commit_value(value)
    @project.write("value.txt", "#{value}\n")
    @project.commit(value)
  end

  # The first run leaves a cache and a stray file behind; the next checks out the second commit.
  def reuse_slot
    @worktrees.check_out(slot, @first)
    FileUtils.mkdir_p(File.join(slot, "vendor", "cache"))
    FileUtils.touch([File.join(slot, "vendor", "cache", "marker"), File.join(slot, "scratch.txt")])
    @worktrees.check_out(slot, @second)
  end
end
