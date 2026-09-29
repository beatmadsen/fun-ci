# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/trunk/tip_reader"

# Which tip of the trunk a check reads, and when it counts as seen
# (architecture.md, Checking against the trunk).
class TestTipReader < Minitest::Test
  NOW = Time.utc(2026, 9, 29, 10)
  MOVED = NOW - 3600
  LAST_FETCH = NOW - 600
  ORIGIN_MAIN = FunCi::Trunk::Ref.new(remote: "origin", branch: "main")
  FETCHED = FunCi::Trunk::Fetched.new(error: nil)
  LAST = FunCi::Persistence::TrunkFetches::Last.new(fetched_at: LAST_FETCH, error: nil)

  # Refs by name, each moved an hour ago.
  class FakeGit
    def initialize(revs) = @revs = revs
    def rev(ref) = @revs[ref]
    def moved_at(_ref) = MOVED
  end

  def test_should_read_fun_ci_s_own_ref_once_fetched
    assert_equal "own", tip({ "refs/fun-ci/trunk/origin/main" => "own", "refs/remotes/origin/main" => "theirs" }).sha
  end

  def test_should_count_a_tip_fetched_just_now_as_seen_now
    assert_equal NOW, tip({ "refs/fun-ci/trunk/origin/main" => "own" }, fetched: FETCHED).seen_at
  end

  def test_should_count_a_tip_not_fetched_this_time_as_seen_at_the_last_fetch
    assert_equal LAST_FETCH, tip({ "refs/fun-ci/trunk/origin/main" => "own" }, last: LAST).seen_at
  end

  def test_should_read_the_remote_tracking_ref_before_fun_ci_has_fetched
    assert_equal "theirs", tip({ "refs/remotes/origin/main" => "theirs" }).sha
  end

  def test_should_count_the_remote_tracking_ref_as_seen_when_it_last_moved
    assert_equal MOVED, tip({ "refs/remotes/origin/main" => "theirs" }).seen_at
  end

  def test_should_read_the_remote_tracking_ref_when_fun_ci_does_not_fetch
    assert_equal "theirs", tip({ "refs/fun-ci/trunk/origin/main" => "own", "refs/remotes/origin/main" => "theirs" },
                               fetching: false).sha
  end

  def test_should_read_a_local_trunk_s_branch
    reader = FunCi::Trunk::TipReader.new(FakeGit.new({ "refs/heads/develop" => "local" }), -> { NOW })

    assert_equal "local", reader.tip(FunCi::Trunk::Ref.new(remote: nil, branch: "develop"), fetching: true).sha
  end

  def test_should_find_no_tip_for_a_trunk_that_does_not_exist
    assert_nil tip({})
  end

  private

  def tip(revs, fetched: nil, last: nil, fetching: true)
    FunCi::Trunk::TipReader.new(FakeGit.new(revs), -> { NOW })
                           .tip(ORIGIN_MAIN, fetching: fetching, fetched: fetched, last: last)
  end
end
