# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_repos"
require "fun_ci/trunk/first_fetch"
require "fun_ci/persistence/database"
require "fun_ci/persistence/trunk_fetches"

# What the post-commit hook says before a project's first fetch of its trunk
# (acceptance-tests.md, AT-11.20): the run itself is in the background,
# where nothing it prints is seen.
class TestFirstFetch < Minitest::Test
  def setup
    @repos = TrunkRepos.create
    @db = FunCi::Persistence::Database.connection(File.join(@repos.project, "..", "db.sqlite3"))
    FunCi::Persistence::Database.migrate!(@db)
  end

  def teardown
    @db.close
    @repos.remove
  end

  def test_should_announce_a_project_s_first_fetch
    assert_match(%r{\Afun-ci: fetching origin/main into refs/fun-ci/}, notice)
  end

  def test_should_announce_nothing_once_the_project_has_fetched
    FunCi::Persistence::TrunkFetches.new(@db, @repos.project).finished(FunCi::Trunk::Fetched.new(error: nil),
                                                                       at: Time.now)

    assert_nil notice
  end

  def test_should_announce_nothing_when_the_project_does_not_fetch
    Dir.mkdir(File.join(@repos.project, ".fun-ci"))
    File.write(File.join(@repos.project, ".fun-ci", "config"), "trunk_fetch: false\n")

    assert_nil notice
  end

  private

  def notice = FunCi::Trunk::FirstFetch.notice(@repos.project, @db)
end
