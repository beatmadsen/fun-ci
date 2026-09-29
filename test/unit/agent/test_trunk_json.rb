# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_kit"
require "fun_ci/agent/trunk_json"

# The trunk object of `status --json` (design.md, The trunk). Its
# fields are a published contract: once published, each keeps its name.
class TestTrunkJson < Minitest::Test
  include TrunkKit

  NOW = Time.utc(2026, 9, 29, 10)
  LAST = FunCi::Trunk::LastFetch

  def test_should_give_every_fact_of_a_check
    assert_equal({ state: "conflicts", ref: "origin/main", sha: TRUNK_SHA, as_of: "2026-09-29T09:58:00Z",
                   stale: false, fetch: "none", fetch_error: nil, ahead: 3, behind: 4, files: ["a.rb"], reason: nil,
                   moved_to: "1a2b3c4" },
                 document(MERGE.conflicts(["a.rb"], ahead: 3, behind: 4), moved_to: "1a2b3c4"))
  end

  def test_should_say_the_last_fetch_went_well
    assert_equal "ok", document(MERGE.clean(ahead: 1, behind: 1), fetch: LAST.new(fetched_at: NOW, error: nil))[:fetch]
  end

  def test_should_say_the_last_fetch_failed
    assert_equal "failed",
                 document(MERGE.clean(ahead: 1, behind: 1), fetch: LAST.new(fetched_at: nil, error: "fatal: x"))[:fetch]
  end

  def test_should_give_the_reason_a_check_could_not_be_made
    check = FunCi::Trunk::Check.new(commit: "abc", tip: nil, merge: MERGE.unknown("no trunk found"))

    assert_equal({ state: "unknown", ref: nil, sha: nil, as_of: nil, reason: "no trunk found" },
                 FunCi::Agent::TrunkJson.document(FunCi::Trunk::Shown.of(check, now: NOW))
                                        .slice(:state, :ref, :sha, :as_of, :reason))
  end

  def test_should_give_the_same_fields_while_the_check_is_going
    shown = FunCi::Trunk::Shown.unchecked(started: NOW, now: NOW)

    assert_equal document(MERGE.clean(ahead: 1, behind: 1)).keys, FunCi::Agent::TrunkJson.document(shown).keys
  end

  private

  def document(merge, **facts)
    shown = FunCi::Trunk::Shown.of(trunk_check("abc", merge, seen_at: NOW - 120), now: NOW, **facts)
    FunCi::Agent::TrunkJson.document(shown)
  end
end
