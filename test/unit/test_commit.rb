# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/trigger_params"

# The commit a pipeline tests, and the branch it is on. On a detached HEAD
# (a rebase, a checked-out tag) git names no branch, and the hooks pass "".
class TestCommit < Minitest::Test
  def test_should_name_the_branch_detached_when_git_names_none
    assert_equal "detached", FunCi::Pipeline::Commit.new(sha: "abc1234", branch: "").branch
  end

  def test_should_keep_the_branch_git_names
    assert_equal "main", FunCi::Pipeline::Commit.new(sha: "abc1234", branch: "main").branch
  end
end
