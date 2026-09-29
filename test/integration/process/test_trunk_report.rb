# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_repos"
require "fun_ci/setup/trunk_report"

# `fun-ci check` describes the trunk a real clone has (docs/trunk-conflicts.md, AT-11.41).
class TestTrunkReport < Minitest::Test
  def setup = @repos = TrunkRepos.create
  def teardown = @repos.remove

  def test_should_name_the_remote_s_default_branch
    assert_match(%r{\ATrunk: origin/main \(origin's default branch\)\.},
                 FunCi::Setup::TrunkReport.new(@repos.project).lines.first)
  end
end
