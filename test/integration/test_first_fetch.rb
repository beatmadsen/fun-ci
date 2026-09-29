# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/trunk/first_fetch"
require "fun_ci/persistence/database"
require "fun_ci/persistence/trunk_fetches"

# What the post-commit hook says before a project's first fetch of its trunk
# (acceptance-tests.md, AT-11.20), decided from the project's settings, its
# fetches so far and the refs its git lists.
class TestFirstFetchDecision < Minitest::Test
  RemoteGit = Struct.new(:remotes) do
    def refs
      FunCi::Trunk::Refs.new(remotes: remotes, branches: ["main", *remotes.map { "#{_1}/main" }],
                             heads: remotes.to_h { [_1, "main"] })
    end
  end

  def setup
    @project = Dir.mktmpdir("fun-ci-first-fetch")
    @db = FunCi::Persistence::Database.connection(File.join(@project, "db.sqlite3"))
    FunCi::Persistence::Database.migrate!(@db)
  end

  def teardown
    @db.close
    FileUtils.rm_rf(@project)
  end

  def test_should_announce_a_project_s_first_fetch
    assert_match(%r{\Afun-ci: fetching origin/main into refs/fun-ci/}, notice(["origin"]))
  end

  def test_should_announce_nothing_once_the_project_has_fetched
    FunCi::Persistence::TrunkFetches.new(@db, @project).finished(FunCi::Trunk::Fetched.new(error: nil),
                                                                 at: Time.now)

    assert_nil notice(["origin"])
  end

  def test_should_announce_nothing_for_a_local_trunk
    assert_nil notice([])
  end

  def test_should_announce_nothing_when_the_project_does_not_fetch
    Dir.mkdir(File.join(@project, ".fun-ci"))
    File.write(File.join(@project, ".fun-ci", "config"), "trunk_fetch: false\n")

    assert_nil notice(["origin"])
  end

  private

  def notice(remotes) = FunCi::Trunk::FirstFetch.notice(@project, @db, git: RemoteGit.new(remotes))
end
