# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/trunk/checker"

# A commit checked against the trunk the project names or has, fetched first
# when it is time to (docs/trunk-conflicts.md).
class TestTrunkChecker < Minitest::Test
  MERGE = FunCi::Trunk::Merge
  ANSWER = FunCi::Trunk::MergeCheck::Answer
  NOW = Time.utc(2026, 9, 29, 10)
  Config = Data.define(:trunk, :trunk_fetch)
  FETCHED = FunCi::Trunk::Fetched.new(error: nil)

  # A repository whose origin/main is at fff0000 in both refs; the commit is two ahead of it.
  class FakeGit
    def refs = FunCi::Trunk::Refs.new(remotes: ["origin"], branches: %w[origin/main develop], heads: {})

    def rev(ref)
      %w[refs/remotes/origin/main refs/fun-ci/trunk/origin/main refs/heads/develop].include?(ref) && "fff0000"
    end

    def moved_at(_ref) = NOW
    def counts(_commit, _trunk) = ANSWER.new(status: 0, out: "2\t0\n", err: "")
  end

  # Starts a fetch as pid 4242 and finds it fetched.
  class FakeFetch
    attr_reader :started

    def start(ref)
      @started = ref
      yield 4242
      :started
    end

    def finish(_started, deadline:) = deadline && FETCHED
  end

  # Fetches whose interval allows one or not.
  Fetches = Data.define(:due) do
    def claim(now:, interval:) = interval && due && now
    def last = nil
  end

  def test_should_find_how_the_commit_would_merge_with_the_trunk
    assert_equal MERGE.clean(ahead: 2, behind: 0), check.check.merge
  end

  def test_should_begin_no_check_when_the_project_says_none
    checker = checker(Config.new(trunk: "none", trunk_fetch: 300), FakeFetch.new)

    assert_nil checker.start("abc1234", Fetches.new(due: true))
  end

  def test_should_say_the_named_trunk_does_not_exist
    assert_equal MERGE.unknown("origin/nosuch doesn't exist; set trunk: in .fun-ci/config"),
                 check(trunk: "origin/nosuch").check.merge
  end

  def test_should_say_no_trunk_was_found
    git = FakeGit.new
    def git.refs = FunCi::Trunk::Refs.new(remotes: [], branches: ["feat/x"], heads: {})
    checker = FunCi::Trunk::Checker.new(git, Config.new(trunk: nil, trunk_fetch: 300), FakeFetch.new, -> { NOW })

    assert_equal MERGE.unknown("no trunk found; set trunk: in .fun-ci/config"),
                 checker.finish(checker.start("abc1234", Fetches.new(due: true))).check.merge
  end

  def test_should_fetch_a_remote_trunk_when_it_is_time_to
    assert_equal FETCHED, check.fetched
  end

  def test_should_give_the_fetch_s_pid_before_it_runs
    pids = []
    checker(Config.new(trunk: nil, trunk_fetch: 300), FakeFetch.new).start("abc1234", Fetches.new(due: true)) do |pid|
      pids << pid
    end

    assert_equal [4242], pids
  end

  def test_should_not_fetch_before_the_interval_has_passed
    assert_nil check(due: false).fetched
  end

  def test_should_not_fetch_when_the_project_says_not_to
    assert_nil check(trunk_fetch: nil).fetched
  end

  def test_should_not_fetch_a_local_trunk
    assert_nil check(trunk: "develop").fetched
  end

  private

  def check(trunk: nil, trunk_fetch: 300, due: true)
    checker = checker(Config.new(trunk: trunk, trunk_fetch: trunk_fetch), FakeFetch.new)
    checker.finish(checker.start("abc1234", Fetches.new(due: due)) { |_pid| nil })
  end

  def checker(config, fetch) = FunCi::Trunk::Checker.new(FakeGit.new, config, fetch, -> { NOW })
end
