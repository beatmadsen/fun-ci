# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_repos"
require "fun_ci/trunk/first_fetch"
require "fun_ci/persistence/database"

# What the post-commit hook says before a project's first fetch of its trunk
# (acceptance-tests.md, AT-11.20), read from a real clone's refs; what it
# decides from them is test/integration/test_first_fetch.rb.
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

  def test_should_announce_the_first_fetch_of_a_clone_s_remote_trunk
    assert_match(%r{\Afun-ci: fetching origin/main into refs/fun-ci/},
                 FunCi::Trunk::FirstFetch.notice(@repos.project, @db))
  end
end
