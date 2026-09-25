# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/workspaces"
require "tmpdir"

# AT-1.7: where a pipeline runs. How a pool waits and hands out slots is
# WorktreePool's (test_worktree_pool.rb).
class TestWorkspaces < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("project")
    FileUtils.mkdir_p(File.join(@dir, ".fun-ci"))
  end

  def teardown = FileUtils.rm_rf(@dir)

  def test_should_give_a_pool_of_two_slots_by_default
    assert_equal 2, FunCi::Pipeline::Workspaces.for(@dir, "abc1234").size
  end

  def test_should_give_a_pool_of_the_size_the_config_file_asks_for
    File.write(File.join(@dir, ".fun-ci", "config"), "worktree_slots: 3\n")

    assert_equal 3, FunCi::Pipeline::Workspaces.for(@dir, "abc1234").size
  end

  def test_should_run_a_root_commit_s_null_sha_in_the_project_itself
    assert_equal FunCi::Pipeline::InPlace.new(@dir), FunCi::Pipeline::Workspaces.for(@dir, "0" * 40)
  end
end
