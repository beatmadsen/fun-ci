# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require "fun_ci/pipeline/worktrees"

# A slot's git-ignored outputs are only as right as its last run's commit. One
# a project names under `clean` goes when the slot moves to a commit that
# doesn't descend from its last one, as when another branch ran there, and
# stays while the slot follows one line of history, keeping its build warm.
class TestWorktreesClean < Minitest::Test
  def setup
    @project = GitProject.create
    @project.write(".gitignore", "out/\nvendor/\n")
    base = commit_value("base")
    @later = commit_value("later")
    @side = side_commit(base)
    @worktrees = FunCi::Pipeline::Worktrees.new(@project.dir)
  end

  def teardown = @project.remove

  def test_should_remove_a_named_output_when_the_slot_moves_off_its_line_of_history
    ran_with_outputs(@later)
    @worktrees.check_out(slot, @side, clean: ["out"])

    refute_path_exists File.join(slot, "out", "model.glb")
  end

  def test_should_keep_an_ignored_file_it_was_not_told_to_clean
    ran_with_outputs(@later)
    @worktrees.check_out(slot, @side, clean: ["out"])

    assert_path_exists File.join(slot, "vendor", "cache")
  end

  def test_should_keep_a_named_output_while_the_slot_follows_its_line_of_history
    ran_with_outputs(@later)
    @worktrees.check_out(slot, commit_value("newer"), clean: ["out"])

    assert_path_exists File.join(slot, "out", "model.glb")
  end

  def test_should_say_a_slot_it_cleaned_is_cold
    ran_with_outputs(@later)

    assert @worktrees.check_out(slot, @side, clean: ["out"])
  end

  def test_should_not_say_a_slot_is_cold_when_it_cleaned_nothing
    ran_with_outputs(@later)

    refute @worktrees.check_out(slot, @side, clean: [])
  end

  private

  def slot = File.join(@worktrees.root, "slot-0")

  # The slot ran `sha` and left an output and a cache, both git-ignored.
  def ran_with_outputs(sha)
    @worktrees.check_out(slot, sha)
    FileUtils.mkdir_p([File.join(slot, "out"), File.join(slot, "vendor")])
    FileUtils.touch([File.join(slot, "out", "model.glb"), File.join(slot, "vendor", "cache")])
  end

  def commit_value(value)
    @project.write("value.txt", "#{value}\n")
    @project.commit(value)
  end

  # A commit on a branch made from base, so not a descendant of later.
  def side_commit(base)
    @project.git("checkout", "-q", "-b", "side", base)
    commit_value("side").tap { @project.git("checkout", "-q", "-") }
  end
end
