# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/settings"

# The trunk settings in .fun-ci/config, none of which ever stops a pipeline
# (architecture.md, Checking against the trunk).
class TestSettingsTrunk < Minitest::Test
  def test_should_name_no_trunk_when_nothing_says_which
    assert_nil settings(nil).trunk
  end

  def test_should_give_the_trunk_named
    assert_equal "origin/develop", settings("trunk: origin/develop\n").trunk
  end

  def test_should_name_no_trunk_when_the_one_given_is_not_a_name
    assert_nil settings("trunk: [main]\n").trunk
  end

  def test_should_find_nothing_wrong_with_a_trunk_that_is_not_a_name
    assert_empty settings("trunk: [main]\n").errors
  end

  def test_should_fetch_the_trunk_every_five_minutes_when_nothing_says_otherwise
    assert_equal 300, settings(nil).trunk_fetch
  end

  def test_should_fetch_the_trunk_as_often_as_asked
    assert_equal 600, settings("trunk_fetch: 10m\n").trunk_fetch
  end

  def test_should_not_fetch_the_trunk_when_told_false
    assert_nil settings("trunk_fetch: false\n").trunk_fetch
  end

  def test_should_fetch_every_five_minutes_when_the_interval_given_is_unreadable
    assert_equal 300, settings("trunk_fetch: often\n").trunk_fetch
  end

  private

  def settings(text) = FunCi::Setup::Settings.new(text)
end
