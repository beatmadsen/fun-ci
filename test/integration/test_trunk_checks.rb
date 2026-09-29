# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/trunk_kit"
require "fun_ci/persistence/database"
require "fun_ci/persistence/trunk_checks"

# Checks of a project's commits against its trunk, written once per commit and trunk SHA.
class TestTrunkChecks < Minitest::Test
  include DatabaseTestSetup
  include TrunkKit

  SEEN = Time.utc(2026, 9, 29, 10, 0, 0)
  CONFLICTS = MERGE.conflicts(["lib/cart.rb"], ahead: 3, behind: 4)

  def setup
    setup_test_db
    @checks = FunCi::Persistence::TrunkChecks.new(@db, "/project")
  end

  def teardown = teardown_test_db

  def test_should_give_back_the_recorded_check_as_the_commit_s_latest
    @checks.record(trunk_check("abc1234", CONFLICTS, seen_at: SEEN), checked_at: SEEN)

    assert_equal trunk_check("abc1234", CONFLICTS, seen_at: SEEN), @checks.latest("abc1234")
  end

  def test_should_take_the_check_against_the_trunk_seen_last_as_the_latest
    @checks.record(trunk_check("abc1234", CONFLICTS, seen_at: SEEN + 60, sha: "bbb"), checked_at: SEEN)
    @checks.record(trunk_check("abc1234", CONFLICTS, seen_at: SEEN, sha: "aaa"), checked_at: SEEN)

    assert_equal "bbb", @checks.latest("abc1234").tip.sha
  end

  def test_should_keep_the_first_check_of_a_pair_recorded_twice
    @checks.record(trunk_check("abc1234", MERGE.clean(ahead: 3, behind: 4), seen_at: SEEN), checked_at: SEEN)
    @checks.record(trunk_check("abc1234", CONFLICTS, seen_at: SEEN), checked_at: SEEN)

    assert_equal "clean", @checks.latest("abc1234").merge.outcome
  end

  def test_should_not_find_another_project_s_check_of_the_same_commit
    FunCi::Persistence::TrunkChecks.new(@db, "/elsewhere").record(trunk_check("abc1234", CONFLICTS, seen_at: SEEN),
                                                                  checked_at: SEEN)

    assert_nil @checks.latest("abc1234")
  end
end
