# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require "fun_ci/pipeline/trigger_params"

# A trigger names its commit by whatever revision it was given; the run is
# kept under the commit's full SHA, which agents look runs up by (AT-9.2).
class TestCommitResolver < Minitest::Test
  def setup
    @project = GitProject.create
    @sha = @project.commit_empty("First")
  end

  def teardown = @project.remove

  def test_should_give_the_full_sha_of_a_short_one
    assert_equal @sha, resolved(@sha[0, 7])
  end

  def test_should_give_the_full_sha_of_a_revision_named_otherwise
    assert_equal @sha, resolved("HEAD")
  end

  def test_should_give_nothing_for_a_commit_the_repository_does_not_have
    assert_nil resolved("deadbeef000000")
  end

  private

  def resolved(rev) = Dir.chdir(@project.dir) { FunCi::Pipeline::Seams.full_sha(rev) }
end
