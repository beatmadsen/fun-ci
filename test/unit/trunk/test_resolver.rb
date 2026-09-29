# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/trunk/resolver"

# Which ref is the trunk (acceptance-tests.md, AT-11.9).
class TestTrunkResolver < Minitest::Test
  REF = FunCi::Trunk::Ref
  REFS = FunCi::Trunk::Refs

  def test_should_take_a_configured_remote_branch
    assert_equal REF.new(remote: "origin", branch: "develop"),
                 pick("origin/develop", REFS.new(remotes: ["origin"], branches: [], heads: {}))
  end

  def test_should_take_a_configured_local_branch
    assert_equal REF.new(remote: nil, branch: "release/2"),
                 pick("release/2", REFS.new(remotes: ["origin"], branches: [], heads: {}))
  end

  def test_should_take_the_remote_s_default_branch
    assert_equal REF.new(remote: "origin", branch: "trunk"),
                 pick(nil, REFS.new(remotes: ["origin"], branches: ["origin/main"], heads: { "origin" => "trunk" }))
  end

  def test_should_take_the_first_usual_trunk_name_the_remote_has
    assert_equal REF.new(remote: "origin", branch: "master"),
                 pick(nil, REFS.new(remotes: ["origin"], branches: %w[origin/develop origin/master], heads: {}))
  end

  def test_should_take_the_only_remote_when_none_is_called_origin
    assert_equal REF.new(remote: "upstream", branch: "main"),
                 pick(nil, REFS.new(remotes: ["upstream"], branches: ["upstream/main"], heads: {}))
  end

  def test_should_take_a_local_branch_without_a_remote
    assert_equal REF.new(remote: nil, branch: "develop"),
                 pick(nil, REFS.new(remotes: [], branches: %w[feat/x develop], heads: {}))
  end

  def test_should_find_no_trunk_when_no_usual_name_exists
    assert_nil pick(nil, REFS.new(remotes: ["origin"], branches: ["origin/feat/x"], heads: {}))
  end

  private

  def pick(setting, refs) = FunCi::Trunk::Resolver.pick(setting, refs)
end
