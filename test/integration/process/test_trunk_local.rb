# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_repos"
require "fun_ci/trunk/local"
require "fun_ci/persistence/trunk_recording"

# The trunk as the project's git has it now, read and checked without fetching (docs/trunk-conflicts.md).
class TestTrunkLocal < Minitest::Test
  ORIGIN_MAIN = FunCi::Trunk::Tip.new(remote: "origin", branch: "main", sha: "old", seen_at: Time.now)
  # Fetches that would let a fetch go, so a check that fetched would see the teammate's commit.
  NO_FETCHES = FunCi::Persistence::TrunkRecording::NoFetches.new

  def setup = @repos = TrunkRepos.create
  def teardown = @repos.remove

  def test_should_say_where_the_trunk_is_now
    @repos.upstream("a.txt" => "a\n")
    @repos.git(@repos.project, "fetch", "-q")

    assert_equal @repos.git(@repos.project, "rev-parse", "origin/main").strip, local.now_at(ORIGIN_MAIN)
  end

  def test_should_read_the_project_s_settings_from_a_directory_inside_it
    Dir.mkdir(File.join(@repos.project, "lib"))
    Dir.mkdir(File.join(@repos.project, ".fun-ci"))
    File.write(File.join(@repos.project, ".fun-ci", "config"), "trunk: none\n")
    sha = @repos.work("b.txt" => "b\n")

    assert_nil FunCi::Trunk::Local.new(File.join(@repos.project, "lib")).check(sha, NO_FETCHES)
  end

  def test_should_check_against_the_trunk_without_fetching_it
    @repos.upstream("a.txt" => "a\n")
    sha = @repos.work("b.txt" => "b\n")

    assert_equal FunCi::Trunk::Merge.clean(ahead: 1, behind: 0), local.check(sha, NO_FETCHES).merge
  end

  private

  def local = FunCi::Trunk::Local.new(@repos.project)
end
