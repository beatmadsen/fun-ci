# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require "fun_ci/cli"
require "fun_ci/pipeline/worktree_pool"

# AT-1.11: `fun-ci prune` in a real repository whose pool has checked out a
# worktree.
class TestCliPrune < Minitest::Test
  def setup
    @project = GitProject.create
    @project.write("README", "hi\n")
    @sha = @project.commit("first")
    @pool = FunCi::Pipeline::WorktreePool.new(FunCi::Pipeline::Worktrees.new(@project.dir), size: 1)
    @pool.acquire(@sha).release
  end

  def teardown = @project.remove

  def test_should_leave_git_with_only_the_main_worktree
    prune

    assert_equal 1, @project.git("worktree", "list").lines.size
  end

  def test_should_say_how_many_worktrees_it_removed
    assert_equal "Removed 1 fun-ci worktree.\n", prune.stdout.string
  end

  def test_should_fail_while_a_pipeline_is_running
    slot = @pool.acquire(@sha)

    assert_equal 1, prune.code
  ensure
    slot.release
  end

  private

  Result = Struct.new(:code, :stdout)

  def prune
    io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: StringIO.new)
    Result.new(Dir.chdir(@project.dir) { FunCi::Cli.run(["prune"], io: io) }, io.stdout)
  end
end
