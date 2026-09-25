# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/git_environment"

# Git hooks run with variables naming the repository that ran them, such as
# GIT_INDEX_FILE=.git/index. Every git command fun-ci runs, and every stage
# script, must find its own repository instead.
class TestGitEnvironment < Minitest::Test
  %w[GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_COMMON_DIR GIT_OBJECT_DIRECTORY].each do |name|
    define_method(:"test_should_unset_#{name.downcase}") do
      assert_includes FunCi::Pipeline::GitEnvironment::CLEAN, name
    end
  end

  def test_should_unset_each_one_rather_than_set_it
    assert_equal [nil], FunCi::Pipeline::GitEnvironment::CLEAN.values.uniq
  end
end
