# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_repos"
require "fun_ci/trunk/checker"
require "fun_ci/persistence/trunk_recording"

# A commit checked against the trunk it fetches, in real repositories (docs/trunk-conflicts.md, AT-11.1, AT-11.2).
class TestTrunkChecker < Minitest::Test
  def setup = @repos = TrunkRepos.create
  def teardown = @repos.remove

  def test_should_find_a_clean_merge_when_both_sides_changed_different_lines
    @repos.upstream("shared.txt" => "ONE\ntwo\nthree\n")
    sha = @repos.work("shared.txt" => "one\ntwo\nTHREE\n")

    assert_equal FunCi::Trunk::Merge.clean(ahead: 1, behind: 1), check(sha).merge
  end

  def test_should_find_the_conflicting_files_when_both_sides_changed_the_same_lines
    @repos.upstream("shared.txt" => "one\nTWO\nthree\n")
    sha = @repos.work("shared.txt" => "one\n2\nthree\n")

    assert_equal FunCi::Trunk::Merge.conflicts(["shared.txt"], ahead: 1, behind: 1), check(sha).merge
  end

  private

  # Fetches the trunk first, as a run does when its interval allows.
  def check(sha)
    checker = FunCi::Trunk::Checker.for(@repos.project, env: {})
    checker.finish(checker.start(sha, FunCi::Persistence::TrunkRecording::NoFetches.new) { |_pid| nil }).check
  end
end
