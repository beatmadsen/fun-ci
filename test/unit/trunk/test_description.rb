# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/trunk/description"

# What `fun-ci check` says about the trunk (docs/trunk-conflicts.md, fun-ci check).
class TestTrunkDescription < Minitest::Test
  REFS = FunCi::Trunk::Refs
  ORIGIN = REFS.new(remotes: ["origin"], branches: %w[origin/main origin/develop], heads: { "origin" => "main" })
  FETCHES = "fun-ci fetches it in the background, at most every 5 minutes; " \
            "set trunk_fetch: false in .fun-ci/config to stop."

  def test_should_name_the_remote_s_default_branch_and_how_it_is_fetched
    assert_equal ["Trunk: origin/main (origin's default branch). #{FETCHES}"], lines(nil, 300, ORIGIN)
  end

  def test_should_name_a_configured_trunk_as_configured
    assert_match(%r{\ATrunk: origin/develop \(trunk: in \.fun-ci/config\)\.},
                 lines("origin/develop", 300, ORIGIN).first)
  end

  def test_should_name_the_usual_trunk_name_found_on_the_remote
    refs = REFS.new(remotes: ["origin"], branches: ["origin/master"], heads: {})

    assert_match(%r{\ATrunk: origin/master \(the first usual trunk name on origin\)\.}, lines(nil, 300, refs).first)
  end

  def test_should_name_a_local_trunk_and_say_nothing_of_fetching
    assert_equal ["Trunk: develop (a local branch)."],
                 lines(nil, 300, REFS.new(remotes: [], branches: ["develop"], heads: {}))
  end

  def test_should_say_a_trunk_is_not_fetched_when_fetching_is_off
    assert_equal ["Trunk: origin/main (origin's default branch). fun-ci doesn't fetch it (trunk_fetch: false)."],
                 lines(nil, nil, ORIGIN)
  end

  def test_should_warn_when_no_trunk_is_found
    assert_equal ["Warning: no trunk found, so runs check none; set trunk: in .fun-ci/config"],
                 lines(nil, 300, REFS.new(remotes: [], branches: [], heads: {}))
  end

  def test_should_say_the_project_checks_no_trunk
    assert_equal ["Trunk: none (trunk: none in .fun-ci/config), so runs check none."], lines("none", 300, ORIGIN)
  end

  def test_should_announce_a_first_fetch_with_the_setting_that_stops_it
    assert_equal "fun-ci: fetching origin/main into refs/fun-ci/ now and at most every 5 minutes, touching none of " \
                 "your refs; set trunk_fetch: false in .fun-ci/config to stop.",
                 FunCi::Trunk::Description.first_fetch(FunCi::Trunk::Ref.new(remote: "origin", branch: "main"), 300)
  end

  private

  def lines(setting, interval, refs) = FunCi::Trunk::Description.lines(setting: setting, interval: interval, refs: refs)
end
